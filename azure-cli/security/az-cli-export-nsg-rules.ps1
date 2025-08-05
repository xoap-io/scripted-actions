<#
.SYNOPSIS
    Export all NSG rules to JSON or CSV for audit, compliance, or migration.
.DESCRIPTION
    This script exports all rules in a specified NSG to JSON or CSV, with advanced filtering and output options.
.PARAMETER NsgName
    Name of the NSG.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER ExportFormat
    Format for export (JSON/CSV).
.PARAMETER OutputPath
    Path for export file.
.EXAMPLE
    .\az-cli-export-nsg-rules.ps1 -NsgName "web-nsg" -ResourceGroup "rg-web" -ExportFormat "CSV"
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
    [ValidateSet('JSON','CSV')]
    [string]$ExportFormat = 'JSON',
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
$rules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --output json | ConvertFrom-Json
if (-not $rules) { Write-Host "No rules found." -ForegroundColor Yellow; exit 0 }
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$path = if ($OutputPath) { $OutputPath } else { "./nsg-rules-$NsgName-$timestamp.$ExportFormat" }
switch ($ExportFormat) {
    'JSON' { $rules | ConvertTo-Json -Depth 10 | Out-File -FilePath $path -Encoding UTF8 }
    'CSV' { $rules | Select-Object name,priority,direction,access,protocol,sourceAddressPrefix,sourcePortRange,destinationAddressPrefix,destinationPortRange | Export-Csv -Path $path -NoTypeInformation }
}
Write-Host "✅ Exported to $path" -ForegroundColor Cyan
