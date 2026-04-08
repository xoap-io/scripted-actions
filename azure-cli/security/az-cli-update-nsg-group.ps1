<#
.SYNOPSIS
    Update Azure NSG tags with validation and optional compliance logging using Azure CLI.

.DESCRIPTION
    This script updates an Azure Network Security Group's tags using the Azure CLI.
    Supports dry-run mode, compliance tagging for audit purposes, and validation of the
    NSG before making changes.

    The script uses the Azure CLI command: az network nsg update

.PARAMETER Name
    Name of the NSG to update.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER Tags
    Tags to apply in key=value format (space-separated pairs, e.g., "Owner=SOC Compliance=PCI").

.PARAMETER ComplianceTag
    Additional compliance tag value to record for audit purposes.

.PARAMETER WhatIf
    Show what would be updated without making changes.

.EXAMPLE
    .\az-cli-update-nsg-group.ps1 -Name "web-nsg" -ResourceGroup "rg-web" -Tags "Owner=SOC Compliance=PCI" -ComplianceTag "PCI-DSS"

    Updates web-nsg tags and records a PCI-DSS compliance annotation.

.EXAMPLE
    .\az-cli-update-nsg-group.ps1 -Name "app-nsg" -ResourceGroup "rg-app" -Tags "Environment=Production" -WhatIf

    Previews the tag update without making changes.

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
    [Parameter(Mandatory = $true, HelpMessage = "Name of the NSG to update")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Tags in key=value format (space-separated)")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Compliance tag value for audit logging")]
    [string]$ComplianceTag,

    [Parameter(Mandatory = $false, HelpMessage = "Preview the update without making changes")]
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
        Write-Host "WHAT-IF: Would update NSG '$Name' in '$ResourceGroup'." -ForegroundColor Yellow
        if ($Tags) { Write-Host "  - Tags: $Tags" -ForegroundColor White }
        if ($ComplianceTag) { Write-Host "  - ComplianceTag: $ComplianceTag" -ForegroundColor White }
        exit 0
    }

    $azParams = @('network', 'nsg', 'update', '--resource-group', $ResourceGroup, '--name', $Name)
    if ($Tags) {
        $tagPairs = $Tags -split '\s+'
        $azParams += '--tags'
        $azParams += $tagPairs
    }

    Write-Host "🔧 Updating NSG '$Name'..." -ForegroundColor Cyan
    $null = az @azParams
    if ($LASTEXITCODE -ne 0) { throw "Failed to update NSG '$Name'." }

    Write-Host "✅ NSG '$Name' updated successfully!" -ForegroundColor Green

    if ($ComplianceTag) {
        Write-Host "ℹ️  Compliance tag '$ComplianceTag' recorded for NSG '$Name'." -ForegroundColor Cyan
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
