<#
.SYNOPSIS
    Restore a previously backed-up Azure NSG rule from a JSON backup file.
.DESCRIPTION
    This script restores an NSG rule from a backup JSON file, with validation and conflict detection. Supports dry-run mode and confirmation prompts.
.PARAMETER BackupPath
    Path to the backup JSON file.
.PARAMETER NsgName
    Name of the NSG to restore the rule to.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER WhatIf
    Show what would be restored without making changes.
.PARAMETER Force
    Skip confirmation prompts.
.EXAMPLE
    .\az-cli-restore-nsg-rule.ps1 -BackupPath "./nsg-rule-backup-AllowHTTP-20250805.json" -NsgName "web-nsg" -ResourceGroup "rg-web"
.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BackupPath,
    [Parameter(Mandatory = $true)]
    [string]$NsgName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    [Parameter(Mandatory = $false)]
    [switch]$Force
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
if (-not (Test-Path $BackupPath)) { Write-Error "Backup file not found."; exit 1 }
$backup = Get-Content -Path $BackupPath | ConvertFrom-Json
$rule = if ($backup.Rule) { $backup.Rule } else { $backup }
Write-Host "🔍 Restoring rule '$($rule.name)' to NSG '$NsgName' in resource group '$ResourceGroup'..." -ForegroundColor Cyan
if ($WhatIf) {
    Write-Host "WHAT-IF: The following rule would be restored:" -ForegroundColor Yellow
    $rule | Format-List
    exit 0
}
if (-not $Force) {
    $confirm = Read-Host "Type 'RESTORE' to confirm restoration, or 'CANCEL' to abort"
    if ($confirm -ne 'RESTORE') { Write-Host "Operation cancelled." -ForegroundColor Yellow; exit 0 }
}
# Check for existing rule conflict
$existing = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $rule.name --output json 2>$null | ConvertFrom-Json
if ($existing) {
    Write-Warning "A rule named '$($rule.name)' already exists. Restoration will overwrite the existing rule."
    if (-not $Force) {
        $confirm = Read-Host "Type 'OVERWRITE' to proceed, or 'CANCEL' to abort"
        if ($confirm -ne 'OVERWRITE') { Write-Host "Operation cancelled." -ForegroundColor Yellow; exit 0 }
    }
}
$cmd = "az network nsg rule create --resource-group '$ResourceGroup' --nsg-name '$NsgName' --name '$($rule.name)' --priority $($rule.priority) --direction '$($rule.direction)' --access '$($rule.access)' --protocol '$($rule.protocol)' --source-address-prefixes '$($rule.sourceAddressPrefix)' --source-port-ranges '$($rule.sourcePortRange)' --destination-address-prefixes '$($rule.destinationAddressPrefix)' --destination-port-ranges '$($rule.destinationPortRange)'"
Invoke-Expression $cmd
Write-Host "✅ Rule '$($rule.name)' restored successfully!" -ForegroundColor Green
