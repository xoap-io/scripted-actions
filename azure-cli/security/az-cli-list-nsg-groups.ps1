<#
.SYNOPSIS
    List all Azure Network Security Groups in a subscription or resource group using Azure CLI.

.DESCRIPTION
    This script lists all Azure Network Security Groups (NSGs) in a subscription or optionally
    filtered by resource group, location, or tag using the Azure CLI. Supports export of results
    to JSON or CSV for compliance documentation.

    The script uses the Azure CLI command: az network nsg list

.PARAMETER ResourceGroup
    Name of the Azure Resource Group (optional, lists all NSGs in subscription if not specified).

.PARAMETER Location
    Filter NSGs by Azure region.

.PARAMETER Tag
    Filter NSGs by tag in key=value format (e.g., "Environment=Production").

.PARAMETER Export
    Export results to a file.

.PARAMETER ExportFormat
    Format for the export file (JSON or CSV).

.PARAMETER OutputPath
    Path for the export file. Defaults to a timestamped file in the current directory.

.EXAMPLE
    .\az-cli-list-nsg-groups.ps1 -ResourceGroup "rg-web" -Location "eastus"

    Lists all NSGs in rg-web located in eastus.

.EXAMPLE
    .\az-cli-list-nsg-groups.ps1 -Tag "Environment=Production" -Export -ExportFormat "CSV"

    Lists all production NSGs and exports to CSV.

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
    [Parameter(Mandatory = $false, HelpMessage = "Name of the Azure Resource Group (optional)")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by Azure region")]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by tag in key=value format")]
    [string]$Tag,

    [Parameter(Mandatory = $false, HelpMessage = "Export results to a file")]
    [switch]$Export,

    [Parameter(Mandatory = $false, HelpMessage = "Export format (JSON or CSV)")]
    [ValidateSet('JSON', 'CSV')]
    [string]$ExportFormat = 'JSON',

    [Parameter(Mandatory = $false, HelpMessage = "Path for the export file")]
    [string]$OutputPath
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

    Write-Host "🔍 Retrieving NSGs..." -ForegroundColor Cyan
    if ($ResourceGroup) {
        $nsgs = az network nsg list --resource-group $ResourceGroup --output json | ConvertFrom-Json
    } else {
        $nsgs = az network nsg list --output json | ConvertFrom-Json
    }

    if (-not $nsgs) {
        Write-Host "ℹ️  No NSGs found." -ForegroundColor Yellow
        exit 0
    }

    if ($Location) {
        $nsgs = $nsgs | Where-Object { $_.location -eq $Location }
    }
    if ($Tag) {
        $key, $value = $Tag -split '='
        $nsgs = $nsgs | Where-Object { $_.tags[$key] -eq $value }
    }

    Write-Host "📋 Found $($nsgs.Count) NSG(s):" -ForegroundColor Green
    foreach ($nsg in $nsgs) {
        Write-Host "  - $($nsg.name) [Location: $($nsg.location), RG: $($nsg.resourceGroup)]" -ForegroundColor White
    }

    if ($Export) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $extension = $ExportFormat.ToLower()
        $path = if ($OutputPath) { $OutputPath } else { "./nsg-groups-$timestamp.$extension" }
        switch ($ExportFormat) {
            'JSON' {
                $nsgs | ConvertTo-Json -Depth 10 | Out-File -FilePath $path -Encoding UTF8
            }
            'CSV' {
                $nsgs | Select-Object name, location, resourceGroup, tags |
                    Export-Csv -Path $path -NoTypeInformation
            }
        }
        Write-Host "✅ Exported to: $path" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
