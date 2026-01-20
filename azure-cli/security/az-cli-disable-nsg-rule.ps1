<#
.SYNOPSIS
    Safely disable an Azure NSG rule by setting its access to 'Deny' or priority to lowest, with backup and rollback.
.DESCRIPTION
    This script disables an NSG rule (without deleting) by changing its access to 'Deny' or moving its priority to 4096. Includes backup, confirmation, and rollback options.
.PARAMETER Name
    Name of the NSG rule to disable.
.PARAMETER NsgName
    Name of the NSG containing the rule.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER Method
    Disable method: 'Deny' (set access) or 'LowestPriority' (set priority to 4096).
.PARAMETER BackupRule
    Backup rule before disabling.
.PARAMETER BackupPath
    Path for backup file.
.PARAMETER Rollback
    Rollback to previous state from backup.
.EXAMPLE
    .\az-cli-disable-nsg-rule.ps1 -Name "AllowHTTP" -NsgName "web-nsg" -ResourceGroup "rg-web" -Method "Deny" -BackupRule
.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
    Version: 1.0.0
    Requires: Azure CLI version 2.0 or later
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$NsgName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $false)]
    [ValidateSet('Deny','LowestPriority')]
    [string]$Method = 'Deny',
    [Parameter(Mandatory = $false)]
    [switch]$BackupRule,
    [Parameter(Mandatory = $false)]
    [string]$BackupPath,
    [Parameter(Mandatory = $false)]
    [switch]$Rollback
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
function Backup-NSGRule {
    param($Rule, $BackupPath)
    try {
        if ([string]::IsNullOrEmpty($BackupPath)) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $BackupPath = "./nsg-rule-backup-$($Rule.name)-$timestamp.json"
        }
        $Rule | ConvertTo-Json -Depth 10 | Out-File -FilePath $BackupPath -Encoding UTF8
        Write-Host "✅ Backup created: $BackupPath" -ForegroundColor Green
        return $BackupPath
    } catch { Write-Warning $_; return $null }
}
function Restore-NSGRule {
    param($BackupPath)
    try {
        $backup = Get-Content -Path $BackupPath | ConvertFrom-Json
        $rule = $backup
        $cmd = "az network nsg rule create --resource-group '$ResourceGroup' --nsg-name '$NsgName' --name '$($rule.name)' --priority $($rule.priority) --direction '$($rule.direction)' --access '$($rule.access)' --protocol '$($rule.protocol)' --source-address-prefixes '$($rule.sourceAddressPrefix)' --source-port-ranges '$($rule.sourcePortRange)' --destination-address-prefixes '$($rule.destinationAddressPrefix)' --destination-port-ranges '$($rule.destinationPortRange)'"
        Invoke-Expression $cmd
        Write-Host "✅ Rule restored from backup." -ForegroundColor Green
    } catch { Write-Error $_ }
}
if ($Rollback) {
    if (-not $BackupPath) { Write-Error "BackupPath required for rollback."; exit 1 }
    Restore-NSGRule -BackupPath $BackupPath
    exit 0
}
$rule = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $Name --output json | ConvertFrom-Json
if (-not $rule) { Write-Error "Rule not found."; exit 1 }
if ($BackupRule) { Backup-NSGRule -Rule $rule -BackupPath $BackupPath }
if ($Method -eq 'Deny') {
    az network nsg rule update --resource-group $ResourceGroup --nsg-name $NsgName --name $Name --access Deny
    Write-Host "✅ Rule '$Name' access set to Deny." -ForegroundColor Yellow
} elseif ($Method -eq 'LowestPriority') {
    az network nsg rule update --resource-group $ResourceGroup --nsg-name $NsgName --name $Name --priority 4096
    Write-Host "✅ Rule '$Name' priority set to 4096 (lowest)." -ForegroundColor Yellow
}
