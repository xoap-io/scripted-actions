<#
.SYNOPSIS
    Queries AWS Cost Explorer for cost and usage data using the AWS CLI.

.DESCRIPTION
    This script retrieves cost and usage data from AWS Cost Explorer for a
    specified date range. Results can be grouped by service, region, or usage
    type and output as a formatted table, exported CSV, or JSON file. CSV and
    JSON exports are written to the current directory with a timestamped
    filename.
    Uses the following AWS CLI command:
    aws ce get-cost-and-usage

.PARAMETER StartDate
    The start date for the cost query in yyyy-MM-dd format (inclusive).

.PARAMETER EndDate
    The end date for the cost query in yyyy-MM-dd format (exclusive).

.PARAMETER Granularity
    The time granularity of the results.
    Valid values: DAILY, MONTHLY. Defaults to MONTHLY.

.PARAMETER GroupBy
    The dimension to group costs by.
    Valid values: SERVICE, REGION, USAGE_TYPE, None. Defaults to SERVICE.

.PARAMETER OutputFormat
    The output format for results.
    Valid values: Table, CSV, JSON. Defaults to Table.

.EXAMPLE
    .\aws-cli-get-cost-and-usage.ps1 `
        -StartDate "2026-01-01" `
        -EndDate "2026-04-01" `
        -Granularity "MONTHLY" `
        -GroupBy "SERVICE" `
        -OutputFormat "Table"

.EXAMPLE
    .\aws-cli-get-cost-and-usage.ps1 `
        -StartDate "2026-03-01" `
        -EndDate "2026-04-01" `
        -Granularity "DAILY" `
        -GroupBy "REGION" `
        -OutputFormat "CSV"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ce/get-cost-and-usage.html

.COMPONENT
    AWS CLI Monitoring
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Start date for the cost query in yyyy-MM-dd format (inclusive).")]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$StartDate,

    [Parameter(Mandatory = $true, HelpMessage = "End date for the cost query in yyyy-MM-dd format (exclusive).")]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$EndDate,

    [Parameter(Mandatory = $false, HelpMessage = "Time granularity of results: DAILY or MONTHLY. Defaults to MONTHLY.")]
    [ValidateSet('DAILY', 'MONTHLY')]
    [string]$Granularity = 'MONTHLY',

    [Parameter(Mandatory = $false, HelpMessage = "Dimension to group costs by: SERVICE, REGION, USAGE_TYPE, or None. Defaults to SERVICE.")]
    [ValidateSet('SERVICE', 'REGION', 'USAGE_TYPE', 'None')]
    [string]$GroupBy = 'SERVICE',

    [Parameter(Mandatory = $false, HelpMessage = "Output format: Table, CSV, or JSON. Defaults to Table.")]
    [ValidateSet('Table', 'CSV', 'JSON')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Querying AWS Cost Explorer ($StartDate to $EndDate, $Granularity)" -ForegroundColor Green

    $ceArgs = @(
        'ce', 'get-cost-and-usage',
        '--time-period', "Start=$StartDate,End=$EndDate",
        '--granularity', $Granularity,
        '--metrics', 'BlendedCost',
        '--output', 'json'
    )

    if ($GroupBy -ne 'None') {
        $ceArgs += '--group-by', "Type=DIMENSION,Key=$GroupBy"
    }

    Write-Host "🔍 Fetching cost data..." -ForegroundColor Cyan

    $result = aws @ceArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve cost and usage data: $result"
    }

    $ceData = $result | ConvertFrom-Json

    # Parse results into flat records
    $records = @()
    foreach ($period in $ceData.ResultsByTime) {
        $timePeriod = "$($period.TimePeriod.Start) to $($period.TimePeriod.End)"
        if ($GroupBy -ne 'None' -and $period.Groups) {
            foreach ($group in $period.Groups) {
                $records += [PSCustomObject]@{
                    TimePeriod = $timePeriod
                    GroupKey   = ($group.Keys -join ', ')
                    Amount     = [double]$group.Metrics.BlendedCost.Amount
                    Unit       = $group.Metrics.BlendedCost.Unit
                }
            }
        } else {
            $records += [PSCustomObject]@{
                TimePeriod = $timePeriod
                GroupKey   = 'Total'
                Amount     = [double]$period.Total.BlendedCost.Amount
                Unit       = $period.Total.BlendedCost.Unit
            }
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    switch ($OutputFormat) {
        'Table' {
            Write-Host "📊 Cost and Usage Report:" -ForegroundColor Blue
            $records | Format-Table -AutoSize
        }
        'CSV' {
            $exportPath = "aws-cost-usage-$timestamp.csv"
            $records | Export-Csv -Path $exportPath -NoTypeInformation
            Write-Host "✅ CSV exported to: $((Resolve-Path $exportPath).Path)" -ForegroundColor Green
        }
        'JSON' {
            $exportPath = "aws-cost-usage-$timestamp.json"
            $records | ConvertTo-Json -Depth 5 | Out-File -FilePath $exportPath -Encoding utf8
            Write-Host "✅ JSON exported to: $((Resolve-Path $exportPath).Path)" -ForegroundColor Green
        }
    }

    $total = ($records | Measure-Object -Property Amount -Sum).Sum
    $unit  = if ($records.Count -gt 0) { $records[0].Unit } else { 'USD' }

    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Period       : $StartDate to $EndDate"
    Write-Host "   Granularity  : $Granularity"
    Write-Host "   GroupBy      : $GroupBy"
    Write-Host "   Total Cost   : $([math]::Round($total, 4)) $unit"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
