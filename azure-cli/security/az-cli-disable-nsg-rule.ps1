<#
.SYNOPSIS
    Disable an Azure NSG rule by setting its access to Deny using Azure CLI.

.DESCRIPTION
    This script disables a specified Azure Network Security Group rule by updating its access
    property to Deny using the Azure CLI. Supports dry-run mode and optional backup of the
    original rule configuration before making changes.

    The script uses the Azure CLI command: az network nsg rule update

.PARAMETER Name
    Name of the NSG rule to disable.

.PARAMETER NsgName
    Name of the Network Security Group containing the rule.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER BackupRule
    Create a JSON backup of the rule before disabling it.

.PARAMETER BackupPath
    Path for the backup file. Defaults to a timestamped file in the current directory.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER WhatIf
    Preview the operation without making any changes.

.EXAMPLE
    .\az-cli-disable-nsg-rule.ps1 -Name "AllowHTTP" -NsgName "web-nsg" -ResourceGroup "rg-web" -BackupRule

    Disables the AllowHTTP rule after creating a backup.

.EXAMPLE
    .\az-cli-disable-nsg-rule.ps1 -Name "TempRule" -NsgName "app-nsg" -ResourceGroup "rg-app" -WhatIf

    Previews disabling TempRule without making changes.

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
    [Parameter(Mandatory = $true, HelpMessage = "Name of the NSG rule to disable")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Name,

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

    [Parameter(Mandatory = $false, HelpMessage = "Create a JSON backup before disabling")]
    [switch]$BackupRule,

    [Parameter(Mandatory = $false, HelpMessage = "Path for the backup file")]
    [string]$BackupPath,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Preview the operation without making changes")]
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

    # Get rule
    Write-Host "🔍 Retrieving rule '$Name' from NSG '$NsgName'..." -ForegroundColor Cyan
    $rule = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $Name --output json 2>$null | ConvertFrom-Json
    if (-not $rule) { throw "Rule '$Name' not found in NSG '$NsgName'." }

    if ($rule.access -eq 'Deny') {
        Write-Host "ℹ️  Rule '$Name' is already set to Deny. No changes needed." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "ℹ️  Rule '$Name' current access: $($rule.access)" -ForegroundColor Blue

    if ($WhatIf) {
        Write-Host "WHAT-IF: Would set rule '$Name' access from '$($rule.access)' to 'Deny'." -ForegroundColor Yellow
        exit 0
    }

    # Backup if requested
    if ($BackupRule) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $bPath = if ($BackupPath) { $BackupPath } else { "./nsg-rule-backup-$Name-$timestamp.json" }
        @{ Rule = $rule } | ConvertTo-Json -Depth 10 | Out-File -FilePath $bPath -Encoding UTF8
        Write-Host "✅ Rule backed up to: $bPath" -ForegroundColor Green
    }

    if (-not $Force) {
        $confirm = Read-Host "Disable rule '$Name' (set access to Deny)? Type 'yes' to confirm"
        if ($confirm -ne 'yes') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Host "🔧 Disabling rule '$Name'..." -ForegroundColor Cyan
    $null = az network nsg rule update --resource-group $ResourceGroup --nsg-name $NsgName --name $Name --access Deny
    if ($LASTEXITCODE -ne 0) { throw "Failed to disable rule '$Name'." }

    Write-Host "✅ Rule '$Name' has been disabled (access set to Deny)." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
