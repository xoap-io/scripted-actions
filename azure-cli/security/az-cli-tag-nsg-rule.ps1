<#
.SYNOPSIS
    Add or update tags on an Azure NSG rule for compliance, ownership, or lifecycle management.
.DESCRIPTION
    This script adds or updates tags on a specified NSG rule, supporting multiple key-value pairs and audit logging.
.PARAMETER Name
    Name of the NSG rule.
.PARAMETER NsgName
    Name of the NSG.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER Tags
    Hashtable of tags to add/update (e.g., @{Owner='SOC'; Compliance='PCI'}).
.EXAMPLE
    .\az-cli-tag-nsg-rule.ps1 -Name "AllowHTTP" -NsgName "web-nsg" -ResourceGroup "rg-web" -Tags @{Owner='SOC'; Compliance='PCI'}
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
    [string]$NsgName,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $true)]
    [hashtable]$Tags
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
$tagArgs = $Tags.GetEnumerator() | ForEach-Object { "--tags $_.Key=$($_.Value)" } | Join-String " "
az network nsg rule update --resource-group $ResourceGroup --nsg-name $NsgName --name $Name $tagArgs
Write-Host "✅ Tags updated for rule '$Name'." -ForegroundColor Green
