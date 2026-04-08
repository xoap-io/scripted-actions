<#
.SYNOPSIS
    Export all rules from an Azure NSG to JSON or CSV for audit, compliance, or migration using Azure CLI.

.DESCRIPTION
    This script exports all rules in a specified Azure Network Security Group (NSG) to a JSON
    or CSV file using the Azure CLI. Useful for compliance audits, documentation, or migrating
    rules between environments.

    The script uses the Azure CLI command: az network nsg rule list

.PARAMETER NsgName
    Name of the NSG.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group.

.PARAMETER ExportFormat
    Format for export (JSON or CSV).

.PARAMETER OutputPath
    Path for export file. Defaults to a timestamped file in the current directory.

.EXAMPLE
    .\az-cli-export-nsg-rules.ps1 -NsgName "web-nsg" -ResourceGroup "rg-web" -ExportFormat "CSV"

    Exports all rules from web-nsg to a CSV file.

.EXAMPLE
    .\az-cli-export-nsg-rules.ps1 -NsgName "app-nsg" -ResourceGroup "rg-app" -ExportFormat "JSON" -OutputPath "./exports/app-nsg-rules.json"

    Exports all rules to a specified JSON file path.

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
    https://docs.microsoft.com/en-us/cli/azure/network/nsg/rule

.COMPONENT
    Azure CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$NsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

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

    Write-Host "🔍 Retrieving rules from NSG '$NsgName'..." -ForegroundColor Cyan
    $rules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --output json | ConvertFrom-Json
    if (-not $rules) {
        Write-Host "ℹ️  No rules found in NSG '$NsgName'." -ForegroundColor Yellow
        exit 0
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $extension = $ExportFormat.ToLower()
    $path = if ($OutputPath) { $OutputPath } else { "./nsg-rules-$NsgName-$timestamp.$extension" }

    switch ($ExportFormat) {
        'JSON' {
            $rules | ConvertTo-Json -Depth 10 | Out-File -FilePath $path -Encoding UTF8
        }
        'CSV' {
            $rules | Select-Object name, priority, direction, access, protocol,
                sourceAddressPrefix, sourcePortRange,
                destinationAddressPrefix, destinationPortRange |
                Export-Csv -Path $path -NoTypeInformation
        }
    }

    Write-Host "✅ Exported $($rules.Count) rule(s) to: $path" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
