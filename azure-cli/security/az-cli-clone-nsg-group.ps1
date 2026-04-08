<#
.SYNOPSIS
    Clone an Azure Network Security Group to a new NSG using Azure CLI.

.DESCRIPTION
    This script clones all rules from a source Azure Network Security Group (NSG) to a new
    destination NSG using the Azure CLI. Useful for promoting NSG configurations between
    environments or duplicating security policies. Creates the destination NSG if it does not exist.

    The script uses the Azure CLI commands: az network nsg create, az network nsg rule create

.PARAMETER SourceNsgName
    Name of the source Network Security Group to clone.

.PARAMETER DestinationNsgName
    Name of the destination Network Security Group to create/populate.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group for the operation.

.PARAMETER DestinationResourceGroup
    Name of the destination Resource Group. Defaults to the source ResourceGroup.

.PARAMETER Location
    Azure region for the destination NSG. Defaults to the source NSG location.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER WhatIf
    Preview the clone operation without making any changes.

.EXAMPLE
    .\az-cli-clone-nsg-group.ps1 -SourceNsgName "dev-nsg" -DestinationNsgName "prod-nsg" -ResourceGroup "rg-security"

    Clones dev-nsg to prod-nsg within the same resource group.

.EXAMPLE
    .\az-cli-clone-nsg-group.ps1 -SourceNsgName "web-nsg" -DestinationNsgName "web-nsg-clone" -ResourceGroup "rg-source" -DestinationResourceGroup "rg-dest" -WhatIf

    Previews cloning web-nsg to a different resource group.

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
    https://docs.microsoft.com/en-us/cli/azure/network/nsg

.COMPONENT
    Azure CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the source Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$SourceNsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the destination Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$DestinationNsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group for the source NSG")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the destination Resource Group (defaults to source)")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$DestinationResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Azure region for the destination NSG")]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Preview the operation without making changes")]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

try {
    # Validate Azure CLI
    Write-Host "🔍 Validating Azure CLI..." -ForegroundColor Cyan
    $null = az --version
    if ($LASTEXITCODE -ne 0) { throw "Azure CLI is not installed or not functioning correctly" }
    $null = az account show 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Not authenticated to Azure CLI. Please run 'az login' first" }
    Write-Host "✅ Azure CLI validation successful" -ForegroundColor Green

    $destRg = if ($DestinationResourceGroup) { $DestinationResourceGroup } else { $ResourceGroup }

    # Get source NSG
    Write-Host "🔍 Retrieving source NSG '$SourceNsgName'..." -ForegroundColor Cyan
    $sourceNsg = az network nsg show --resource-group $ResourceGroup --name $SourceNsgName --output json | ConvertFrom-Json
    if (-not $sourceNsg) { throw "Source NSG '$SourceNsgName' not found in resource group '$ResourceGroup'." }

    $destLocation = if ($Location) { $Location } else { $sourceNsg.location }
    $customRules = $sourceNsg.securityRules | Where-Object { $_.name -notlike 'Allow*Internet*' -and $_.name -notlike 'DenyAllInBound*' }

    Write-Host "📋 Source NSG has $($customRules.Count) custom rule(s) to clone." -ForegroundColor Blue

    if ($WhatIf) {
        Write-Host "WHAT-IF: Would create NSG '$DestinationNsgName' in '$destRg' ($destLocation) and clone $($customRules.Count) rule(s)." -ForegroundColor Yellow
        exit 0
    }

    if (-not $Force) {
        $confirm = Read-Host "Clone '$SourceNsgName' to '$DestinationNsgName'? Type 'yes' to confirm"
        if ($confirm -ne 'yes') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Create destination NSG
    Write-Host "🔧 Creating destination NSG '$DestinationNsgName'..." -ForegroundColor Cyan
    $null = az network nsg create --resource-group $destRg --name $DestinationNsgName --location $destLocation
    if ($LASTEXITCODE -ne 0) { throw "Failed to create NSG '$DestinationNsgName'." }
    Write-Host "✅ NSG '$DestinationNsgName' created." -ForegroundColor Green

    # Clone rules
    $cloned = 0
    foreach ($rule in $customRules) {
        Write-Host "🔧 Cloning rule '$($rule.name)' (priority: $($rule.priority))..." -ForegroundColor Cyan
        $azParams = @(
            'network', 'nsg', 'rule', 'create',
            '--resource-group', $destRg,
            '--nsg-name', $DestinationNsgName,
            '--name', $rule.name,
            '--priority', $rule.priority,
            '--direction', $rule.direction,
            '--access', $rule.access,
            '--protocol', $rule.protocol,
            '--source-address-prefixes', $rule.sourceAddressPrefix,
            '--source-port-ranges', $rule.sourcePortRange,
            '--destination-address-prefixes', $rule.destinationAddressPrefix,
            '--destination-port-ranges', $rule.destinationPortRange
        )
        if ($rule.description) { $azParams += '--description'; $azParams += $rule.description }
        $null = az @azParams
        if ($LASTEXITCODE -eq 0) {
            $cloned++
            Write-Host "  ✅ Rule '$($rule.name)' cloned." -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Failed to clone rule '$($rule.name)'." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "📊 Summary: $cloned of $($customRules.Count) rules cloned to '$DestinationNsgName'." -ForegroundColor Blue
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
