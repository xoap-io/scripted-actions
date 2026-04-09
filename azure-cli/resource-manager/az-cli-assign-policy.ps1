<#
.SYNOPSIS
    Assign a built-in or custom Azure Policy using the Azure CLI.

.DESCRIPTION
    This script assigns an Azure Policy definition to a specified scope using the Azure CLI.
    The policy can be identified by display name or definition ID. If ResourceGroupName is provided,
    the scope is set to that resource group; otherwise it defaults to the current subscription.
    The script uses the following Azure CLI commands:
    az policy definition list (to look up policy by name)
    az policy assignment create --name $AssignmentName --policy $PolicyId --scope $Scope

.PARAMETER PolicyName
    Defines the display name or definition ID of the Azure Policy to assign.

.PARAMETER AssignmentName
    Defines the name of the policy assignment.

.PARAMETER Scope
    Defines the full scope ID for the assignment (e.g. subscription or management group ID).
    Defaults to the current subscription if not specified and ResourceGroupName is not set.

.PARAMETER ResourceGroupName
    Defines the name of the Resource Group to scope the assignment to.
    If provided, overrides the Scope parameter.

.PARAMETER Description
    Defines an optional description for the policy assignment.

.PARAMETER EnforcementMode
    Defines whether the policy is enforced or in audit mode.
    Valid values: Default (enforce), DoNotEnforce (audit only). Default: Default.

.PARAMETER Parameters
    Defines a JSON string of parameter values for parameterized policy definitions.

.EXAMPLE
    .\az-cli-assign-policy.ps1 -PolicyName "Audit VMs without disaster recovery configured" -AssignmentName "audit-vm-dr"

.EXAMPLE
    .\az-cli-assign-policy.ps1 -PolicyName "Allowed locations" -AssignmentName "allowed-locations-rg" -ResourceGroupName "rg-production" -EnforcementMode "Default" -Parameters '{"listOfAllowedLocations":{"value":["eastus","westus2"]}}'

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/policy/assignment

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The display name or definition ID of the Azure Policy to assign")]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the policy assignment")]
    [ValidateNotNullOrEmpty()]
    [string]$AssignmentName,

    [Parameter(Mandatory = $false, HelpMessage = "The full scope ID for the assignment (defaults to current subscription)")]
    [ValidateNotNullOrEmpty()]
    [string]$Scope,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Resource Group to scope the assignment to")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "An optional description for the policy assignment")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Whether the policy is enforced or in audit mode")]
    [ValidateSet('Default', 'DoNotEnforce')]
    [string]$EnforcementMode = 'Default',

    [Parameter(Mandatory = $false, HelpMessage = "A JSON string of parameter values for parameterized policy definitions")]
    [ValidateNotNullOrEmpty()]
    [string]$Parameters
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Assigning Azure Policy '$PolicyName' as '$AssignmentName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Resolve policy definition ID
    Write-Host "🔍 Resolving policy definition for '$PolicyName'..." -ForegroundColor Cyan
    $policyId = $PolicyName

    # If not a full resource ID, look up by display name
    if ($PolicyName -notmatch '^/') {
        $policyDefJson = az policy definition list `
            --query "[?displayName=='$PolicyName'] | [0]" `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to query policy definitions."
        }

        $policyDef = $policyDefJson | ConvertFrom-Json

        if (-not $policyDef) {
            throw "No policy definition found with display name: '$PolicyName'. Provide the exact display name or a definition ID."
        }

        $policyId = $policyDef.id
        Write-Host "✅ Found policy: $($policyDef.displayName) (ID: $policyId)" -ForegroundColor Green
    }

    # Resolve scope
    if ($ResourceGroupName) {
        # Get subscription ID and build resource group scope
        $subscriptionJson = az account show --output json
        $subscription = $subscriptionJson | ConvertFrom-Json
        $Scope = "/subscriptions/$($subscription.id)/resourceGroups/$ResourceGroupName"
        Write-Host "ℹ️  Scope set to resource group: $Scope" -ForegroundColor Yellow
    }
    elseif (-not $Scope) {
        # Default to current subscription
        $subscriptionJson = az account show --output json
        $subscription = $subscriptionJson | ConvertFrom-Json
        $Scope = "/subscriptions/$($subscription.id)"
        Write-Host "ℹ️  Scope set to current subscription: $Scope" -ForegroundColor Yellow
    }

    # Build the policy assignment arguments
    $assignArgs = @(
        'policy', 'assignment', 'create',
        '--name', $AssignmentName,
        '--policy', $policyId,
        '--scope', $Scope,
        '--enforcement-mode', $EnforcementMode,
        '--output', 'json'
    )

    if ($Description) {
        $assignArgs += '--description'
        $assignArgs += $Description
    }

    if ($Parameters) {
        $assignArgs += '--params'
        $assignArgs += $Parameters
    }

    # Create the assignment
    Write-Host "🔧 Creating policy assignment '$AssignmentName'..." -ForegroundColor Cyan
    $assignmentJson = az @assignArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI policy assignment create command failed with exit code $LASTEXITCODE"
    }

    $assignment = $assignmentJson | ConvertFrom-Json

    Write-Host "`n✅ Policy assignment '$AssignmentName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   AssignmentName:  $($assignment.name)" -ForegroundColor White
    Write-Host "   PolicyId:        $policyId" -ForegroundColor White
    Write-Host "   Scope:           $($assignment.scope)" -ForegroundColor White
    Write-Host "   EnforcementMode: $($assignment.enforcementMode)" -ForegroundColor White
    Write-Host "   AssignmentId:    $($assignment.id)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
