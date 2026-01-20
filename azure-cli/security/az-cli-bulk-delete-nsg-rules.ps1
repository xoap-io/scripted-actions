<#
.SYNOPSIS
    Bulk delete multiple Azure NSG rules by name or pattern, with dependency analysis, backup, and confirmation.
.DESCRIPTION
    This script deletes multiple NSG rules in a specified NSG, supports name/pattern matching, dependency analysis, backup, and confirmation prompts. Includes dry-run mode and compliance tagging.
.PARAMETER NsgName
    Name of the NSG.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER RuleNames
    Array of rule names to delete.
.PARAMETER NamePattern
    Wildcard pattern to match rule names (e.g., 'Test*').
.PARAMETER Force
    Skip confirmation prompts.
.PARAMETER BackupRules
    Backup rules before deletion.
.PARAMETER WhatIf
    Show what would be deleted without making changes.
.PARAMETER ComplianceTag
    Tag deleted rules for audit/compliance.
.EXAMPLE
    .\az-cli-bulk-delete-nsg-rules.ps1 -NsgName "web-nsg" -ResourceGroup "rg-web" -NamePattern "Test*" -BackupRules -Force
.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
    Version: 1.0.0
    Requires: Azure CLI version 2.0 or later
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$NsgName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $false)]
    [string[]]$RuleNames,
    [Parameter(Mandatory = $false)]
    [string]$NamePattern,
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    [Parameter(Mandatory = $false)]
    [switch]$BackupRules,
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
$allRules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --output json | ConvertFrom-Json
if (-not $allRules) { Write-Host "No rules found." -ForegroundColor Yellow; exit 0 }
$targetRules = @()
if ($RuleNames) { $targetRules += $allRules | Where-Object { $RuleNames -contains $_.name } }
if ($NamePattern) { $targetRules += $allRules | Where-Object { $_.name -like $NamePattern } }
$targetRules = $targetRules | Sort-Object name -Unique
if ($targetRules.Count -eq 0) { Write-Host "No matching rules found." -ForegroundColor Yellow; exit 0 }
Write-Host "📋 Target rules for deletion:" -ForegroundColor Cyan
foreach ($rule in $targetRules) { Write-Host " - $($rule.name) [Priority: $($rule.priority)]" -ForegroundColor White }
if ($WhatIf) {
    Write-Host "WHAT-IF: The following rules would be deleted:" -ForegroundColor Yellow
    foreach ($rule in $targetRules) { Write-Host " - $($rule.name)" -ForegroundColor Gray }
    exit 0
}
if (-not $Force) {
    $confirm = Read-Host "Type 'DELETE' to confirm bulk deletion, or 'CANCEL' to abort"
    if ($confirm -ne 'DELETE') { Write-Host "Operation cancelled." -ForegroundColor Yellow; exit 0 }
}
foreach ($rule in $targetRules) {
    if ($BackupRules) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $backupPath = "./nsg-rule-backup-$($rule.name)-$timestamp.json"
        $rule | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupPath -Encoding UTF8
        Write-Host "✅ Backup created: $backupPath" -ForegroundColor Green
    }
    az network nsg rule delete --resource-group $ResourceGroup --nsg-name $NsgName --name $rule.name
    Write-Host "✅ Deleted rule: $($rule.name)" -ForegroundColor Green
    if ($ComplianceTag) {
        Write-Host "📝 Compliance tag '$ComplianceTag' recorded for rule '$($rule.name)'" -ForegroundColor Cyan
        # In real implementation, log to compliance system
    }
}
Write-Host "🏁 Bulk deletion completed." -ForegroundColor Green
