<#
.SYNOPSIS
    Restore a previously backed-up Azure NSG rule from a JSON backup file using Azure CLI.

.DESCRIPTION
    This script restores an Azure Network Security Group rule from a backup JSON file created by
    az-cli-backup-nsg-group.ps1 or az-cli-delete-nsg-rule.ps1 using the Azure CLI.
    Includes conflict detection and supports dry-run mode and confirmation prompts.

    The script uses the Azure CLI command: az network nsg rule create

.PARAMETER BackupPath
    Path to the backup JSON file containing the rule to restore.

.PARAMETER NsgName
    Name of the NSG to restore the rule to.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER WhatIf
    Show what would be restored without making changes.

.PARAMETER Force
    Skip confirmation prompts including overwrite confirmation.

.EXAMPLE
    .\az-cli-restore-nsg-rule.ps1 -BackupPath "./nsg-rule-backup-AllowHTTP-20250805.json" -NsgName "web-nsg" -ResourceGroup "rg-web"

    Restores the AllowHTTP rule from a backup file with confirmation.

.EXAMPLE
    .\az-cli-restore-nsg-rule.ps1 -BackupPath "./backup.json" -NsgName "app-nsg" -ResourceGroup "rg-app" -WhatIf

    Previews the restoration without making any changes.

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
    [Parameter(Mandatory = $true, HelpMessage = "Path to the backup JSON file")]
    [ValidateNotNullOrEmpty()]
    [string]$BackupPath,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the NSG to restore the rule to")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$NsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Preview what would be restored without making changes")]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force
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

    if (-not (Test-Path $BackupPath)) { throw "Backup file not found: $BackupPath" }

    $backup = Get-Content -Path $BackupPath | ConvertFrom-Json
    $rule = if ($backup.Rule) { $backup.Rule } else { $backup }

    Write-Host "🔍 Restoring rule '$($rule.name)' to NSG '$NsgName' in '$ResourceGroup'..." -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "WHAT-IF: The following rule would be restored:" -ForegroundColor Yellow
        $rule | Format-List
        exit 0
    }

    if (-not $Force) {
        $confirm = Read-Host "Type 'RESTORE' to confirm restoration, or anything else to cancel"
        if ($confirm -ne 'RESTORE') {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Check for existing rule conflict
    $existing = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $rule.name --output json 2>$null | ConvertFrom-Json
    if ($existing) {
        Write-Host "⚠️  Rule '$($rule.name)' already exists. Restoration will overwrite it." -ForegroundColor Yellow
        if (-not $Force) {
            $confirm = Read-Host "Type 'OVERWRITE' to proceed, or anything else to cancel"
            if ($confirm -ne 'OVERWRITE') {
                Write-Host "Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    }

    $azParams = @(
        'network', 'nsg', 'rule', 'create',
        '--resource-group', $ResourceGroup,
        '--nsg-name', $NsgName,
        '--name', $rule.name,
        '--priority', $rule.priority,
        '--direction', $rule.direction,
        '--access', $rule.access,
        '--protocol', $rule.protocol,
        '--source-address-prefixes', $rule.sourceAddressPrefix,
        '--source-port-ranges', $rule.sourcePortRange,
        '--destination-address-prefixes', $rule.destinationAddressPrefix,
        '--destination-port-ranges', $rule.destinationPortRange
    )
    if ($rule.description) { $azParams += '--description'; $azParams += $rule.description }

    $null = az @azParams
    if ($LASTEXITCODE -ne 0) { throw "Failed to restore rule '$($rule.name)'." }

    Write-Host "✅ Rule '$($rule.name)' restored successfully!" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
