<#
.SYNOPSIS
    Audit an Azure Network Security Group and export a compliance report using Azure CLI.

.DESCRIPTION
    This script audits a specified Azure Network Security Group (NSG) using the Azure CLI.
    Analyzes all inbound and outbound rules, flags overly permissive entries, and exports a
    timestamped JSON compliance report. Supports dry-run mode and filtering by direction.

    The script uses the Azure CLI command: az network nsg rule list

.PARAMETER NsgName
    Name of the Network Security Group to audit.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER OutputPath
    Path for the audit report file. Defaults to a timestamped file in the current directory.

.PARAMETER Direction
    Filter audit by rule direction (Inbound, Outbound, or Both).

.PARAMETER WhatIf
    Show what would be audited without generating a report file.

.EXAMPLE
    .\az-cli-audit-nsg-group.ps1 -NsgName "web-nsg" -ResourceGroup "rg-web"

    Audits all rules in web-nsg and exports a JSON report.

.EXAMPLE
    .\az-cli-audit-nsg-group.ps1 -NsgName "app-nsg" -ResourceGroup "rg-app" -Direction "Inbound" -WhatIf

    Previews an inbound-only audit without writing a report file.

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
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Network Security Group to audit")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$NsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Path for the audit report file")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, HelpMessage = "Filter audit by rule direction")]
    [ValidateSet('Inbound', 'Outbound', 'Both')]
    [string]$Direction = 'Both',

    [Parameter(Mandatory = $false, HelpMessage = "Preview audit without writing a report file")]
    [switch]$WhatIf
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

    Write-Host "🔍 Auditing NSG '$NsgName' in resource group '$ResourceGroup'..." -ForegroundColor Cyan
    $rules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --output json | ConvertFrom-Json
    if (-not $rules) {
        Write-Host "ℹ️  No rules found in NSG '$NsgName'." -ForegroundColor Yellow
        exit 0
    }

    # Filter by direction if requested
    if ($Direction -ne 'Both') {
        $rules = $rules | Where-Object { $_.direction -eq $Direction }
    }

    # Flag permissive rules
    $permissiveRules = $rules | Where-Object {
        $_.access -eq 'Allow' -and (
            $_.sourceAddressPrefix -eq '*' -or
            $_.destinationAddressPrefix -eq '*' -or
            $_.destinationPortRange -eq '*'
        )
    }

    Write-Host "📋 Total rules: $($rules.Count)" -ForegroundColor Blue
    Write-Host "⚠️  Permissive rules flagged: $($permissiveRules.Count)" -ForegroundColor Yellow

    if ($WhatIf) {
        Write-Host "WHAT-IF: Audit complete. Report would be generated but was skipped due to -WhatIf." -ForegroundColor Yellow
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $reportPath = if ($OutputPath) { $OutputPath } else { "./nsg-audit-$NsgName-$timestamp.json" }
        @{
            NsgName          = $NsgName
            ResourceGroup    = $ResourceGroup
            AuditTimestamp   = $timestamp
            Direction        = $Direction
            TotalRules       = $rules.Count
            PermissiveCount  = $permissiveRules.Count
            Rules            = $rules
            PermissiveRules  = $permissiveRules
        } | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "✅ Audit report exported to: $reportPath" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
