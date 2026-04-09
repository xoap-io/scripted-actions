<#
.SYNOPSIS
    Create a diagnostic setting to send Azure resource logs and metrics to Log Analytics using the Azure CLI.

.DESCRIPTION
    This script creates a diagnostic setting on an Azure resource using the Azure CLI.
    Diagnostic settings route resource logs and metrics to a Log Analytics workspace and/or
    a storage account for archival. Use -EnableAllLogs and -EnableAllMetrics to capture all
    available diagnostic categories.
    The script uses the following Azure CLI command:
    az monitor diagnostic-settings create --resource $ResourceId --name $SettingName

.PARAMETER ResourceId
    Defines the full resource ID of the Azure resource to configure diagnostics on.

.PARAMETER SettingName
    Defines the name of the diagnostic setting.

.PARAMETER WorkspaceId
    Defines the resource ID of the Log Analytics workspace to send logs and metrics to.

.PARAMETER StorageAccountId
    Defines the resource ID of the storage account for archival of logs.

.PARAMETER EnableAllLogs
    If specified, enables all available log categories for the resource.

.PARAMETER EnableAllMetrics
    If specified, enables all available metric categories for the resource.

.PARAMETER RetentionDays
    Defines the retention period in days for logs stored in a storage account (0-365).
    0 means retain indefinitely. Default: 0.

.EXAMPLE
    .\az-cli-create-diagnostic-setting.ps1 -ResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vms/providers/Microsoft.Compute/virtualMachines/vm-prod-01" -SettingName "diag-vm-prod-01" -WorkspaceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod-01" -EnableAllLogs -EnableAllMetrics

.EXAMPLE
    .\az-cli-create-diagnostic-setting.ps1 -ResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-storage/providers/Microsoft.Storage/storageAccounts/mystorageacct" -SettingName "diag-storage-archive" -StorageAccountId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitoring/providers/Microsoft.Storage/storageAccounts/logarchive" -EnableAllLogs -RetentionDays 90

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
    https://learn.microsoft.com/en-us/cli/azure/monitor/diagnostic-settings

.COMPONENT
    Azure CLI Monitor
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The full resource ID of the Azure resource to configure diagnostics on")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceId,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the diagnostic setting")]
    [ValidateNotNullOrEmpty()]
    [string]$SettingName,

    [Parameter(Mandatory = $false, HelpMessage = "The resource ID of the Log Analytics workspace to send logs and metrics to")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId,

    [Parameter(Mandatory = $false, HelpMessage = "The resource ID of the storage account for archival of logs")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountId,

    [Parameter(Mandatory = $false, HelpMessage = "Enable all available log categories for the resource")]
    [switch]$EnableAllLogs,

    [Parameter(Mandatory = $false, HelpMessage = "Enable all available metric categories for the resource")]
    [switch]$EnableAllMetrics,

    [Parameter(Mandatory = $false, HelpMessage = "Retention period in days for storage account archival (0=indefinite, max 365)")]
    [ValidateRange(0, 365)]
    [int]$RetentionDays = 0
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating diagnostic setting '$SettingName' on resource..." -ForegroundColor Green
    Write-Host "   ResourceId: $ResourceId" -ForegroundColor White

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Validate at least one destination is specified
    if (-not $WorkspaceId -and -not $StorageAccountId) {
        throw "At least one destination must be specified: -WorkspaceId or -StorageAccountId."
    }

    # Validate at least one data type is enabled
    if (-not $EnableAllLogs -and -not $EnableAllMetrics) {
        throw "At least one of -EnableAllLogs or -EnableAllMetrics must be specified."
    }

    # Retrieve available diagnostic categories for the resource
    Write-Host "🔍 Retrieving available diagnostic categories for the resource..." -ForegroundColor Cyan
    $categoriesJson = az monitor diagnostic-settings categories list `
        --resource $ResourceId `
        --output json 2>$null

    $logs = @()
    $metrics = @()

    if ($LASTEXITCODE -eq 0 -and $categoriesJson) {
        $categories = $categoriesJson | ConvertFrom-Json

        if ($EnableAllLogs) {
            $logs = $categories.value |
                Where-Object { $_.properties.categoryType -eq 'Logs' -or $_.categoryType -eq 'Logs' } |
                ForEach-Object {
                    @{
                        category        = $_.name
                        enabled         = $true
                        retentionPolicy = @{ enabled = ($RetentionDays -gt 0); days = $RetentionDays }
                    }
                }
        }

        if ($EnableAllMetrics) {
            $metrics = $categories.value |
                Where-Object { $_.properties.categoryType -eq 'Metrics' -or $_.categoryType -eq 'Metrics' } |
                ForEach-Object {
                    @{
                        category        = $_.name
                        enabled         = $true
                        retentionPolicy = @{ enabled = ($RetentionDays -gt 0); days = $RetentionDays }
                    }
                }
        }

        Write-Host "ℹ️  Found $($logs.Count) log categories and $($metrics.Count) metric categories." -ForegroundColor Yellow
    }
    else {
        Write-Host "⚠️  Could not retrieve diagnostic categories. Proceeding with --export-to-resource-specific flag." -ForegroundColor Yellow
    }

    # Build diagnostic setting create arguments
    $diagArgs = @(
        'monitor', 'diagnostic-settings', 'create',
        '--resource', $ResourceId,
        '--name', $SettingName,
        '--output', 'json'
    )

    if ($WorkspaceId) {
        $diagArgs += '--workspace'
        $diagArgs += $WorkspaceId
        Write-Host "ℹ️  Destination: Log Analytics Workspace" -ForegroundColor Yellow
    }

    if ($StorageAccountId) {
        $diagArgs += '--storage-account'
        $diagArgs += $StorageAccountId
        Write-Host "ℹ️  Destination: Storage Account" -ForegroundColor Yellow
    }

    # Build JSON settings for logs and metrics
    if ($logs.Count -gt 0 -or $metrics.Count -gt 0) {
        $settingsJson = @{
            logs    = $logs
            metrics = $metrics
        } | ConvertTo-Json -Depth 10

        $tempSettingsFile = [System.IO.Path]::GetTempFileName() + '.json'
        $settingsJson | Set-Content -Path $tempSettingsFile -Encoding UTF8
        $diagArgs += '--logs'
        $diagArgs += "[$(($logs | ConvertTo-Json -Depth 5 -Compress))]"
        $diagArgs += '--metrics'
        $diagArgs += "[$(($metrics | ConvertTo-Json -Depth 5 -Compress))]"
    }
    else {
        # Fall back to enabling all logs/metrics via flags
        if ($EnableAllLogs) {
            $diagArgs += '--logs'
            $diagArgs += '[{"category":"allLogs","enabled":true}]'
        }
        if ($EnableAllMetrics) {
            $diagArgs += '--metrics'
            $diagArgs += '[{"category":"AllMetrics","enabled":true}]'
        }
    }

    # Create the diagnostic setting
    Write-Host "🔧 Creating diagnostic setting '$SettingName'..." -ForegroundColor Cyan
    $diagJson = az @diagArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI diagnostic-settings create command failed with exit code $LASTEXITCODE"
    }

    $diagSetting = $diagJson | ConvertFrom-Json

    Write-Host "`n✅ Diagnostic setting '$SettingName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   SettingName:   $($diagSetting.name)" -ForegroundColor White
    Write-Host "   ResourceId:    $ResourceId" -ForegroundColor White

    if ($WorkspaceId) {
        Write-Host "   WorkspaceId:   $WorkspaceId" -ForegroundColor White
    }

    if ($StorageAccountId) {
        Write-Host "   StorageAccount: $StorageAccountId" -ForegroundColor White
        Write-Host "   RetentionDays:  $(if ($RetentionDays -eq 0) { 'Indefinite' } else { $RetentionDays })" -ForegroundColor White
    }

    Write-Host "   EnableAllLogs:    $($EnableAllLogs.IsPresent)" -ForegroundColor White
    Write-Host "   EnableAllMetrics: $($EnableAllMetrics.IsPresent)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    # Clean up temp file if created
    if ($tempSettingsFile -and (Test-Path $tempSettingsFile)) {
        Remove-Item -Path $tempSettingsFile -Force -ErrorAction SilentlyContinue
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
