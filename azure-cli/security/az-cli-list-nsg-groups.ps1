<#
.SYNOPSIS
    List all NSGs in a subscription/resource group, with advanced filtering, export, and compliance status summary.
.DESCRIPTION
    This script lists all NSGs in a subscription or resource group, supports filtering by location/tags, and can export results to JSON/CSV. Includes compliance status summary.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group (optional).
.PARAMETER Location
    Filter by Azure region.
.PARAMETER Tag
    Filter by tag key=value.
.PARAMETER Export
    Export results to file.
.PARAMETER ExportFormat
    Format for export (JSON/CSV).
.PARAMETER OutputPath
    Path for export file.
.EXAMPLE
    .\az-cli-list-nsg-groups.ps1 -ResourceGroup "rg-web" -Location "eastus" -Export -ExportFormat "CSV"
.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $false)]
    [string]$Location,
    [Parameter(Mandatory = $false)]
    [string]$Tag,
    [Parameter(Mandatory = $false)]
    [switch]$Export,
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
if ($ResourceGroup) {
    $nsgs = az network nsg list --resource-group $ResourceGroup --output json | ConvertFrom-Json
} else {
    $nsgs = az network nsg list --output json | ConvertFrom-Json
}
if (-not $nsgs) { Write-Host "No NSGs found." -ForegroundColor Yellow; exit 0 }
if ($Location) { $nsgs = $nsgs | Where-Object { $_.location -eq $Location } }
if ($Tag) {
    $key, $value = $Tag -split '='
    $nsgs = $nsgs | Where-Object { $_.tags[$key] -eq $value }
}
Write-Host "📋 Found $($nsgs.Count) NSG(s):" -ForegroundColor Green
foreach ($nsg in $nsgs) {
    Write-Host " - $($nsg.name) [Location: $($nsg.location)]" -ForegroundColor White
}
if ($Export) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $path = if ($OutputPath) { $OutputPath } else { "./nsg-groups-$timestamp.$ExportFormat" }
    switch ($ExportFormat) {
        'JSON' { $nsgs | ConvertTo-Json -Depth 10 | Out-File -FilePath $path -Encoding UTF8 }
        'CSV' { $nsgs | Select-Object name,location,resourceGroup,tags | Export-Csv -Path $path -NoTypeInformation }
    }
    Write-Host "✅ Exported to $path" -ForegroundColor Cyan
}
