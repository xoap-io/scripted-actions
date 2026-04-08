<#
.SYNOPSIS
    Add or update tags on an Azure NSG (at the NSG level) for compliance or lifecycle management using Azure CLI.

.DESCRIPTION
    This script adds or updates tags on an Azure Network Security Group using the Azure CLI.
    Tags are applied at the NSG resource level. Useful for compliance tagging, ownership
    tracking, and lifecycle management of NSG resources.

    The script uses the Azure CLI command: az network nsg update

.PARAMETER NsgName
    Name of the NSG to tag.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER Tags
    Space-separated key=value tag pairs to apply (e.g., "Owner=SOC Compliance=PCI").

.PARAMETER WhatIf
    Preview the tagging operation without making changes.

.EXAMPLE
    .\az-cli-tag-nsg-rule.ps1 -NsgName "web-nsg" -ResourceGroup "rg-web" -Tags "Owner=SOC Compliance=PCI"

    Applies Owner and Compliance tags to web-nsg.

.EXAMPLE
    .\az-cli-tag-nsg-rule.ps1 -NsgName "app-nsg" -ResourceGroup "rg-app" -Tags "Environment=Production" -WhatIf

    Previews applying the Environment tag without making changes.

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
    [Parameter(Mandatory = $true, HelpMessage = "Name of the NSG to tag")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$NsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Space-separated key=value tag pairs to apply")]
    [ValidateNotNullOrEmpty()]
    [string]$Tags,

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

    if ($WhatIf) {
        Write-Host "WHAT-IF: Would apply tags '$Tags' to NSG '$NsgName' in '$ResourceGroup'." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "🔧 Applying tags to NSG '$NsgName'..." -ForegroundColor Cyan
    $tagPairs = $Tags -split '\s+'
    $null = az network nsg update --resource-group $ResourceGroup --name $NsgName --tags $tagPairs
    if ($LASTEXITCODE -ne 0) { throw "Failed to apply tags to NSG '$NsgName'." }

    Write-Host "✅ Tags applied to NSG '$NsgName': $Tags" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
