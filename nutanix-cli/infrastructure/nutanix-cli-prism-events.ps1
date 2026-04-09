<#
.SYNOPSIS
    Query the Prism Central events log using the REST API v3.

.DESCRIPTION
    This script retrieves events from the Nutanix Prism Central events log using the
    REST API v3 (POST /events/list). Events can be filtered by severity level and limited
    by count. Results can be output as a formatted table, JSON, or exported to a timestamped
    CSV or JSON file in the current directory.
    Authentication uses HTTP Basic auth with -SkipCertificateCheck (PowerShell 7+).

.PARAMETER PrismCentralHost
    The FQDN or IP address of the Prism Central instance.

.PARAMETER Username
    The Prism Central username for authentication.

.PARAMETER Password
    The Prism Central password as a SecureString.

.PARAMETER Count
    Maximum number of events to retrieve (1-1000). Default: 50

.PARAMETER SeverityLevel
    Filter events by severity. Valid values: All, Critical, Warning, Info.
    Default: All

.PARAMETER OutputFormat
    Output format for the results. Valid values: Table, JSON, CSV.
    Table and JSON are displayed to the console. CSV and JSON export to a timestamped file.
    Default: Table

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-prism-events.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass -Count 100

    Retrieve the last 100 events as a table.

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-prism-events.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass -SeverityLevel Critical -OutputFormat CSV

    Retrieve critical events and export to a timestamped CSV file.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 7+ (for -SkipCertificateCheck support)

.LINK
    https://www.nutanix.dev/reference/prism_central/v3/

.COMPONENT
    Nutanix REST API PowerShell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The FQDN or IP address of the Prism Central instance.")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentralHost,

    [Parameter(Mandatory = $true, HelpMessage = "The Prism Central username for authentication.")]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory = $true, HelpMessage = "The Prism Central password as a SecureString.")]
    [ValidateNotNull()]
    [SecureString]$Password,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of events to retrieve (1-1000).")]
    [ValidateRange(1, 1000)]
    [int]$Count = 50,

    [Parameter(Mandatory = $false, HelpMessage = "Filter events by severity. Valid values: All, Critical, Warning, Info.")]
    [ValidateSet('All', 'Critical', 'Warning', 'Info')]
    [string]$SeverityLevel = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Output format. Table/JSON display to console; CSV/JSON file exports to a timestamped file.")]
    [ValidateSet('Table', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

$baseUrl = "https://$PrismCentralHost`:9440/api/nutanix/v3"
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
$encodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${plainPassword}"))
$headers = @{
    Authorization  = "Basic $encodedAuth"
    'Content-Type' = 'application/json'
}

try {
    Write-Host "🚀 Starting Nutanix Prism events query..." -ForegroundColor Green
    Write-Host "ℹ️  Prism Central  : $PrismCentralHost" -ForegroundColor Yellow
    Write-Host "ℹ️  Event Count    : $Count" -ForegroundColor Yellow
    Write-Host "ℹ️  Severity Filter: $SeverityLevel" -ForegroundColor Yellow
    Write-Host "ℹ️  Output Format  : $OutputFormat" -ForegroundColor Yellow

    # Build request body
    $listBody = @{
        kind   = 'event'
        length = $Count
    }
    if ($SeverityLevel -ne 'All') {
        $listBody.filter = "severity==$($SeverityLevel.ToUpper())"
    }

    Write-Host "🔍 Retrieving events from Prism Central..." -ForegroundColor Cyan

    $invokeParams = @{
        Method               = 'POST'
        Uri                  = "$baseUrl/events/list"
        Headers              = $headers
        Body                 = ($listBody | ConvertTo-Json -Depth 10)
        SkipCertificateCheck = $true
    }
    $response = Invoke-RestMethod @invokeParams

    $events = $response.entities
    Write-Host "✅ Retrieved $($events.Count) event(s)." -ForegroundColor Green

    if ($events.Count -eq 0) {
        Write-Host "ℹ️  No events found for the specified filter." -ForegroundColor Yellow
        return
    }

    # Build output objects
    $output = $events | ForEach-Object {
        [PSCustomObject]@{
            UUID        = $_.metadata.uuid
            Severity    = $_.status.resources.severity
            SourceEntity= $_.status.resources.source_entity_reference.name
            Message     = ($_.status.resources.message -replace '\s+', ' ')
            CreatedTime = $_.metadata.creation_time
        }
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'

    switch ($OutputFormat) {
        'Table' {
            $output | Format-Table -AutoSize
        }
        'JSON' {
            $fileName = "Nutanix_Events_$timestamp.json"
            $output | ConvertTo-Json -Depth 5 | Out-File -FilePath $fileName -Encoding UTF8
            Write-Host "✅ Events exported to: $fileName" -ForegroundColor Green
        }
        'CSV' {
            $fileName = "Nutanix_Events_$timestamp.csv"
            $output | Export-Csv -Path $fileName -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Events exported to: $fileName" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($plainPassword) { $plainPassword = $null }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
