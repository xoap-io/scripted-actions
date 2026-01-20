<#
.SYNOPSIS
    Backup an Azure NSG (including all rules/tags) to JSON for disaster recovery, migration, or audit.
.DESCRIPTION
    This script backs up an NSG and all its rules/tags to a JSON file, with validation and timestamped output.
.PARAMETER Name
    Name of the NSG to backup.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER OutputPath
    Path for backup file.
.EXAMPLE
    .\az-cli-backup-nsg-group.ps1 -Name "web-nsg" -ResourceGroup "rg-web"
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
    [string]$OutputPath
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
$nsg = az network nsg show --resource-group $ResourceGroup --name $Name --output json | ConvertFrom-Json
if (-not $nsg) { Write-Host "NSG not found." -ForegroundColor Yellow; exit 0 }
$rules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $Name --output json | ConvertFrom-Json
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$path = if ($OutputPath) { $OutputPath } else { "./nsg-backup-$Name-$timestamp.json" }
$backupData = @{ NSG = $nsg; Rules = $rules }
$backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $path -Encoding UTF8
Write-Host "✅ Backup created: $path" -ForegroundColor Green
