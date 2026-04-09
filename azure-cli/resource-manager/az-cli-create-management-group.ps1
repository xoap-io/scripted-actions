<#
.SYNOPSIS
    Create an Azure Management Group using the Azure CLI.

.DESCRIPTION
    This script creates an Azure Management Group using the Azure CLI.
    Management Groups provide a governance scope above subscriptions, enabling
    hierarchical organisation of subscriptions for policy and access management.
    The script uses the following Azure CLI command:
    az account management-group create --name $ManagementGroupId --display-name $DisplayName

.PARAMETER ManagementGroupId
    Defines the unique identifier of the management group (no spaces allowed).

.PARAMETER DisplayName
    Defines the display name of the management group.

.PARAMETER ParentId
    Defines the ID of the parent management group.
    Defaults to the tenant root management group if not specified.

.PARAMETER Description
    Defines an optional description for the management group.

.EXAMPLE
    .\az-cli-create-management-group.ps1 -ManagementGroupId "mg-production" -DisplayName "Production"

.EXAMPLE
    .\az-cli-create-management-group.ps1 -ManagementGroupId "mg-prod-eu" -DisplayName "Production Europe" -ParentId "mg-production" -Description "Production workloads in European regions"

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
    https://learn.microsoft.com/en-us/cli/azure/account/management-group

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The unique identifier of the management group (no spaces)")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-zA-Z0-9_-]+$')]
    [string]$ManagementGroupId,

    [Parameter(Mandatory = $true, HelpMessage = "The display name of the management group")]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the parent management group (defaults to tenant root)")]
    [ValidateNotNullOrEmpty()]
    [string]$ParentId,

    [Parameter(Mandatory = $false, HelpMessage = "An optional description for the management group")]
    [ValidateNotNullOrEmpty()]
    [string]$Description
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating Azure Management Group '$ManagementGroupId' ('$DisplayName')..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Build the management group create arguments
    $mgArgs = @(
        'account', 'management-group', 'create',
        '--name', $ManagementGroupId,
        '--display-name', $DisplayName,
        '--output', 'json'
    )

    if ($ParentId) {
        $mgArgs += '--parent'
        $mgArgs += $ParentId
        Write-Host "ℹ️  Parent management group: $ParentId" -ForegroundColor Yellow
    }
    else {
        Write-Host "ℹ️  No parent specified. Management group will be created under the tenant root." -ForegroundColor Yellow
    }

    # Create the management group
    Write-Host "🔧 Creating management group '$ManagementGroupId'..." -ForegroundColor Cyan
    $mgJson = az @mgArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI management-group create command failed with exit code $LASTEXITCODE"
    }

    $mg = $mgJson | ConvertFrom-Json

    # Get tenant ID
    $accountJson = az account show --output json
    $account = $accountJson | ConvertFrom-Json
    $tenantId = $account.tenantId

    Write-Host "`n✅ Management Group '$ManagementGroupId' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   ManagementGroupId: $($mg.name)" -ForegroundColor White
    Write-Host "   DisplayName:       $($mg.properties.displayName)" -ForegroundColor White
    Write-Host "   TenantId:          $tenantId" -ForegroundColor White
    Write-Host "   Type:              $($mg.type)" -ForegroundColor White

    if ($ParentId) {
        Write-Host "   ParentId:          $ParentId" -ForegroundColor White
    }

    if ($Description) {
        Write-Host "   Description:       $Description" -ForegroundColor White
    }

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Move subscriptions: az account management-group subscription add --name $ManagementGroupId --subscription <subscriptionId>" -ForegroundColor White
    Write-Host "   - Assign policies:    az policy assignment create --scope /providers/Microsoft.Management/managementGroups/$ManagementGroupId" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
