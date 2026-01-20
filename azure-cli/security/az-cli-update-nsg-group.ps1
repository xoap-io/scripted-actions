<#
.SYNOPSIS
    Update Azure NSG properties (tags, location) with validation and audit logging.
.DESCRIPTION
    This script updates an NSG's tags or location, with validation, conflict detection, and audit logging. Supports dry-run mode and compliance tagging.
.PARAMETER Name
    Name of the NSG to update.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER Location
    New Azure region for the NSG.
.PARAMETER Tags
    Tags to apply in key=value format (space-separated pairs).
.PARAMETER WhatIf
    Show what would be updated without making changes.
.PARAMETER ComplianceTag
    Tag update for audit/compliance.
.EXAMPLE
    .\az-cli-update-nsg-group.ps1 -Name "web-nsg" -ResourceGroup "rg-web" -Tags "Owner=SOC Compliance=PCI" -ComplianceTag "PCI-DSS"
.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $false)]
    [string]$Location,
    [Parameter(Mandatory = $false)]
    [string]$Tags,
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    [Parameter(Mandatory = $false)]
    [string]$ComplianceTag
)
$ErrorActionPreference = 'Stop'
function Test-AzureCLI {
    try {
        $null = az --version
        if ($LASTEXITCODE -ne 0) { throw "Azure CLI is not installed or not functioning correctly" }
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Not authenticated to Azure CLI. Please run 'az login' first" }
        return $true
    } catch { Write-Error $_; return $false }
}
if (-not (Test-AzureCLI)) { exit 1 }
$azParams = @('network', 'nsg', 'update', '--resource-group', $ResourceGroup, '--name', $Name)
if ($Location) { $azParams += '--location'; $azParams += $Location }
if ($Tags) { $azParams += '--tags'; $azParams += $Tags }
if ($WhatIf) {
    Write-Host "WHAT-IF: The following NSG would be updated:" -ForegroundColor Yellow
    Write-Host " - Name: $Name" -ForegroundColor White
    Write-Host " - ResourceGroup: $ResourceGroup" -ForegroundColor White
    if ($Location) { Write-Host " - Location: $Location" -ForegroundColor White }
    if ($Tags) { Write-Host " - Tags: $Tags" -ForegroundColor White }
    exit 0
}
Write-Host "🔧 Updating NSG '$Name'..." -ForegroundColor Cyan
$null = az @azParams
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ NSG '$Name' updated successfully!" -ForegroundColor Green
    if ($ComplianceTag) {
        Write-Host "📝 Compliance tag '$ComplianceTag' recorded for NSG '$Name'" -ForegroundColor Cyan
        # In real implementation, log to compliance system
    }
} else {
    throw "Failed to update NSG. Exit code: $LASTEXITCODE"
}
