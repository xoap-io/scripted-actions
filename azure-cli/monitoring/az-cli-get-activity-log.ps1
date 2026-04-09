<#
.SYNOPSIS
    Query the Azure Activity Log using the Azure CLI.

.DESCRIPTION
    This script queries the Azure Activity Log using the Azure CLI and outputs the results
    in the selected format. Results can be exported to a timestamped CSV or JSON file.
    The script uses the following Azure CLI command:
    az monitor activity-log list --resource-group $ResourceGroupName --start-time $StartTime

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group to filter activity log entries by.
    If omitted, queries the subscription-level activity log.

.PARAMETER StartTime
    Defines the start time for the query. Accepts ISO 8601 datetime strings or relative values:
    "1h" (last 1 hour), "24h" (last 24 hours), "7d" (last 7 days). Default: 24h.

.PARAMETER EndTime
    Defines the end time for the query in ISO 8601 format. Defaults to the current time.

.PARAMETER Caller
    Defines a caller filter (UPN or service principal name) to show only operations by that principal.

.PARAMETER Status
    Defines the operation status to filter by.
    Valid values: All, Succeeded, Failed, Started. Default: All.

.PARAMETER OutputFormat
    Defines the output format for results.
    Valid values: Table (console), CSV (file export), JSON (file export). Default: Table.

.EXAMPLE
    .\az-cli-get-activity-log.ps1 -ResourceGroupName "rg-production"

.EXAMPLE
    .\az-cli-get-activity-log.ps1 -ResourceGroupName "rg-production" -StartTime "7d" -Status "Failed" -OutputFormat "CSV"

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
    https://learn.microsoft.com/en-us/cli/azure/monitor/activity-log

.COMPONENT
    Azure CLI Monitor
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Resource Group to filter activity log entries by (omit for subscription-level)")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Start time: ISO 8601 datetime or relative (1h, 24h, 7d). Default: 24h")]
    [ValidateNotNullOrEmpty()]
    [string]$StartTime = '24h',

    [Parameter(Mandatory = $false, HelpMessage = "End time in ISO 8601 format. Defaults to current time.")]
    [ValidateNotNullOrEmpty()]
    [string]$EndTime,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by caller UPN or service principal name")]
    [ValidateNotNullOrEmpty()]
    [string]$Caller,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by operation status: All, Succeeded, Failed, or Started")]
    [ValidateSet('All', 'Succeeded', 'Failed', 'Started')]
    [string]$Status = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Output format: Table (console), CSV (file), or JSON (file)")]
    [ValidateSet('Table', 'CSV', 'JSON')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Querying Azure Activity Log..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Resolve relative start times
    $resolvedStartTime = $StartTime
    if ($StartTime -match '^(\d+)(h|d)$') {
        $amount = [int]$Matches[1]
        $unit = $Matches[2]
        $resolvedStartTime = if ($unit -eq 'h') {
            (Get-Date).AddHours(-$amount).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
        else {
            (Get-Date).AddDays(-$amount).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        }
        Write-Host "ℹ️  Resolved start time: $resolvedStartTime" -ForegroundColor Yellow
    }

    # Default end time
    $resolvedEndTime = $EndTime
    if (-not $EndTime) {
        $resolvedEndTime = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    }

    Write-Host "🔍 Query parameters:" -ForegroundColor Cyan
    Write-Host "   StartTime: $resolvedStartTime" -ForegroundColor White
    Write-Host "   EndTime:   $resolvedEndTime" -ForegroundColor White

    if ($ResourceGroupName) {
        Write-Host "   ResourceGroup: $ResourceGroupName" -ForegroundColor White
    }
    if ($Caller) {
        Write-Host "   Caller:    $Caller" -ForegroundColor White
    }
    if ($Status -ne 'All') {
        Write-Host "   Status:    $Status" -ForegroundColor White
    }

    # Build the activity log query arguments
    $logArgs = @(
        'monitor', 'activity-log', 'list',
        '--start-time', $resolvedStartTime,
        '--end-time', $resolvedEndTime,
        '--output', 'json'
    )

    if ($ResourceGroupName) {
        $logArgs += '--resource-group'
        $logArgs += $ResourceGroupName
    }

    if ($Caller) {
        $logArgs += '--caller'
        $logArgs += $Caller
    }

    if ($Status -ne 'All') {
        $logArgs += '--status'
        $logArgs += $Status
    }

    # Query activity log
    Write-Host "🔧 Fetching activity log entries..." -ForegroundColor Cyan
    $logJson = az @logArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI activity-log list command failed with exit code $LASTEXITCODE"
    }

    $entries = $logJson | ConvertFrom-Json

    Write-Host "✅ Retrieved $($entries.Count) activity log entries." -ForegroundColor Green

    # Output results
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    switch ($OutputFormat) {
        'Table' {
            $entries | Select-Object `
                @{Name = 'Time'; Expression = { $_.eventTimestamp } },
                @{Name = 'Caller'; Expression = { $_.caller } },
                @{Name = 'Operation'; Expression = { $_.operationName.localizedValue } },
                @{Name = 'Status'; Expression = { $_.status.value } },
                @{Name = 'ResourceGroup'; Expression = { $_.resourceGroupName } } |
                Format-Table -AutoSize
        }
        'CSV' {
            $csvFile = "activity-log-$timestamp.csv"
            $entries | Select-Object `
                @{Name = 'Time'; Expression = { $_.eventTimestamp } },
                @{Name = 'Caller'; Expression = { $_.caller } },
                @{Name = 'Operation'; Expression = { $_.operationName.localizedValue } },
                @{Name = 'Status'; Expression = { $_.status.value } },
                @{Name = 'ResourceGroup'; Expression = { $_.resourceGroupName } },
                @{Name = 'CorrelationId'; Expression = { $_.correlationId } } |
                Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8

            Write-Host "📊 CSV exported to: $(Resolve-Path $csvFile)" -ForegroundColor Blue
        }
        'JSON' {
            $jsonFile = "activity-log-$timestamp.json"
            $logJson | Set-Content -Path $jsonFile -Encoding UTF8
            Write-Host "📊 JSON exported to: $(Resolve-Path $jsonFile)" -ForegroundColor Blue
        }
    }

    Write-Host "`n✅ Activity log query completed. $($entries.Count) entries retrieved." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
