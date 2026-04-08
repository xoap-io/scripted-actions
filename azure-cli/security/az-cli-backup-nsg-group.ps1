<#
.SYNOPSIS
    Backup an Azure Network Security Group configuration to a JSON file using Azure CLI.

.DESCRIPTION
    This script exports the complete configuration of an Azure Network Security Group (NSG) —
    including all rules — to a timestamped JSON backup file using the Azure CLI.
    Useful before making changes to NSG rules or for compliance documentation.

    The script uses the Azure CLI command: az network nsg show

.PARAMETER NsgName
    Name of the Network Security Group to back up.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER OutputPath
    Path for the backup file. Defaults to a timestamped file in the current directory.

.EXAMPLE
    .\az-cli-backup-nsg-group.ps1 -NsgName "web-nsg" -ResourceGroup "rg-web"

    Backs up web-nsg to a timestamped JSON file in the current directory.

.EXAMPLE
    .\az-cli-backup-nsg-group.ps1 -NsgName "app-nsg" -ResourceGroup "rg-app" -OutputPath "./backups/app-nsg.json"

    Backs up app-nsg to a specified file path.

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
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Network Security Group to back up")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$NsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Path for the backup file")]
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

    Write-Host "🔍 Retrieving NSG '$NsgName'..." -ForegroundColor Cyan
    $nsg = az network nsg show --resource-group $ResourceGroup --name $NsgName --output json | ConvertFrom-Json
    if (-not $nsg) {
        throw "NSG '$NsgName' not found in resource group '$ResourceGroup'."
    }

    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $backupPath = if ($OutputPath) { $OutputPath } else { "./nsg-backup-$NsgName-$timestamp.json" }

    @{
        BackupTimestamp = $timestamp
        NsgName         = $NsgName
        ResourceGroup   = $ResourceGroup
        NSG             = $nsg
    } | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupPath -Encoding UTF8

    Write-Host "✅ NSG '$NsgName' backed up to: $backupPath" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
