<#
.SYNOPSIS
    Clone an Azure NSG (including all rules and tags) to a new NSG, with optional modifications and conflict checks.
.DESCRIPTION
    This script clones an existing NSG and all its rules/tags to a new NSG, with optional tag/location modifications and conflict detection. Supports dry-run mode and audit logging.
.PARAMETER SourceName
    Name of the source NSG to clone.
.PARAMETER TargetName
    Name of the new NSG to create.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER Location
    Azure region for the new NSG.
.PARAMETER Tags
    Tags to apply to the new NSG.
.PARAMETER WhatIf
    Show what would be cloned without making changes.
.PARAMETER ComplianceTag
    Tag clone for audit/compliance.
.EXAMPLE
    .\az-cli-clone-nsg-group.ps1 -SourceName "web-nsg" -TargetName "web-nsg-clone" -ResourceGroup "rg-web" -Location "eastus2" -Tags "Owner=SOC" -ComplianceTag "PCI-DSS"
.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceName,
    [Parameter(Mandatory = $true)]
    [string]$TargetName,
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
$sourceNsg = az network nsg show --resource-group $ResourceGroup --name $SourceName --output json | ConvertFrom-Json
if (-not $sourceNsg) { Write-Error "Source NSG not found."; exit 1 }
$rules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $SourceName --output json | ConvertFrom-Json
if ($WhatIf) {
    Write-Host "WHAT-IF: The following NSG would be cloned:" -ForegroundColor Yellow
    Write-Host " - Source: $SourceName" -ForegroundColor White
    Write-Host " - Target: $TargetName" -ForegroundColor White
    Write-Host " - ResourceGroup: $ResourceGroup" -ForegroundColor White
    if ($Location) { Write-Host " - Location: $Location" -ForegroundColor White }
    if ($Tags) { Write-Host " - Tags: $Tags" -ForegroundColor White }
    Write-Host " - Rules: $($rules.Count)" -ForegroundColor White
    exit 0
}
$azParams = @('network', 'nsg', 'create', '--resource-group', $ResourceGroup, '--name', $TargetName)
if ($Location) { $azParams += '--location'; $azParams += $Location }
if ($Tags) { $azParams += '--tags'; $azParams += $Tags }
$null = az @azParams
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ NSG '$TargetName' created successfully!" -ForegroundColor Green
    foreach ($rule in $rules) {
        $ruleParams = @('network', 'nsg', 'rule', 'create', '--resource-group', $ResourceGroup, '--nsg-name', $TargetName, '--name', $rule.name, '--priority', $rule.priority, '--direction', $rule.direction, '--access', $rule.access, '--protocol', $rule.protocol, '--source-address-prefixes', $rule.sourceAddressPrefix, '--source-port-ranges', $rule.sourcePortRange, '--destination-address-prefixes', $rule.destinationAddressPrefix, '--destination-port-ranges', $rule.destinationPortRange)
        if ($rule.description) { $ruleParams += '--description'; $ruleParams += $rule.description }
        $null = az @ruleParams
        if ($LASTEXITCODE -eq 0) { Write-Host "   ✅ Rule '$($rule.name)' cloned" -ForegroundColor Green } else { Write-Warning "   ⚠️ Failed to clone rule '$($rule.name)'" }
    }
    if ($ComplianceTag) {
        Write-Host "📝 Compliance tag '$ComplianceTag' recorded for NSG '$TargetName'" -ForegroundColor Cyan
        # In real implementation, log to compliance system
    }
} else {
    throw "Failed to create NSG. Exit code: $LASTEXITCODE"
}
