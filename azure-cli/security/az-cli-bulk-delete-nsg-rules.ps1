<#
.SYNOPSIS
    Bulk delete Azure NSG rules matching a name pattern or priority range using Azure CLI.

.DESCRIPTION
    This script deletes multiple NSG rules from an Azure Network Security Group based on a name
    pattern, priority range, or explicit list of rule names using the Azure CLI.
    Supports dry-run mode and requires confirmation before deleting unless -Force is specified.

    The script uses the Azure CLI command: az network nsg rule delete

.PARAMETER NsgName
    Name of the Network Security Group to operate on.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER NamePattern
    Wildcard pattern to match rule names for bulk deletion (e.g., "Temp-*").

.PARAMETER RuleNames
    Comma-separated list of explicit rule names to delete.

.PARAMETER MinPriority
    Minimum priority value for range-based deletion (inclusive).

.PARAMETER MaxPriority
    Maximum priority value for range-based deletion (inclusive).

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER WhatIf
    Show what would be deleted without making any changes.

.EXAMPLE
    .\az-cli-bulk-delete-nsg-rules.ps1 -NsgName "web-nsg" -ResourceGroup "rg-web" -NamePattern "Temp-*" -WhatIf

    Previews deletion of all rules matching "Temp-*" without making changes.

.EXAMPLE
    .\az-cli-bulk-delete-nsg-rules.ps1 -NsgName "app-nsg" -ResourceGroup "rg-app" -MinPriority 3000 -MaxPriority 4096 -Force

    Deletes all rules with priority between 3000 and 4096 without confirmation.

.EXAMPLE
    .\az-cli-bulk-delete-nsg-rules.ps1 -NsgName "old-nsg" -ResourceGroup "rg-cleanup" -RuleNames "OldRule1,OldRule2"

    Deletes specific named rules with confirmation prompt.

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

    [Parameter(Mandatory = $false, HelpMessage = "Wildcard pattern to match rule names")]
    [string]$NamePattern,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of explicit rule names to delete")]
    [string]$RuleNames,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum priority value for range-based deletion")]
    [ValidateRange(100, 4096)]
    [int]$MinPriority,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum priority value for range-based deletion")]
    [ValidateRange(100, 4096)]
    [int]$MaxPriority,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Preview deletions without making changes")]
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

    # Get all rules
    Write-Host "🔍 Retrieving rules from NSG '$NsgName'..." -ForegroundColor Cyan
    $allRules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --output json | ConvertFrom-Json
    if (-not $allRules) { throw "No rules found or NSG '$NsgName' not found." }

    # Build target list
    $targetRules = @()
    if ($NamePattern) {
        $targetRules += $allRules | Where-Object { $_.name -like $NamePattern }
    }
    if ($RuleNames) {
        $explicit = $RuleNames -split ',' | ForEach-Object { $_.Trim() }
        $targetRules += $allRules | Where-Object { $_.name -in $explicit }
    }
    if ($MinPriority -or $MaxPriority) {
        $min = if ($MinPriority) { $MinPriority } else { 100 }
        $max = if ($MaxPriority) { $MaxPriority } else { 4096 }
        $targetRules += $allRules | Where-Object { $_.priority -ge $min -and $_.priority -le $max }
    }

    # Deduplicate
    $targetRules = $targetRules | Sort-Object -Property name -Unique

    if ($targetRules.Count -eq 0) {
        Write-Host "ℹ️  No rules matched the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "📋 Rules targeted for deletion: $($targetRules.Count)" -ForegroundColor Blue
    $targetRules | ForEach-Object { Write-Host "  - $($_.name) (Priority: $($_.priority))" -ForegroundColor White }

    if ($WhatIf) {
        Write-Host "WHAT-IF: No rules were deleted." -ForegroundColor Yellow
        exit 0
    }

    if (-not $Force) {
        $confirm = Read-Host "Type 'DELETE' to confirm bulk deletion, or anything else to cancel"
        if ($confirm -ne 'DELETE') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    $deleted = 0
    foreach ($rule in $targetRules) {
        Write-Host "🔧 Deleting rule '$($rule.name)'..." -ForegroundColor Cyan
        az network nsg rule delete --resource-group $ResourceGroup --nsg-name $NsgName --name $rule.name
        if ($LASTEXITCODE -eq 0) {
            $deleted++
            Write-Host "  ✅ Deleted" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Failed to delete rule '$($rule.name)'" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "📊 Summary: $deleted of $($targetRules.Count) rules deleted." -ForegroundColor Blue
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
