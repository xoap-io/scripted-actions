<#
.SYNOPSIS
    Retrieve Entra ID sign-in audit logs via the Microsoft Graph API.

.DESCRIPTION
    This script retrieves Entra ID (Azure AD) sign-in audit logs using the Microsoft Graph API.
    Supports OData filtering, date range filtering, failure-only mode, and multiple output
    formats including Table, CSV, and JSON.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: GET /auditLogs/signIns

.PARAMETER Top
    Maximum number of sign-in log entries to return. Defaults to 100.

.PARAMETER Filter
    Optional OData filter string to narrow results.
    Example: "userPrincipalName eq 'user@domain.com'"

.PARAMETER StartDateTime
    Optional. Return only sign-ins on or after this datetime. Accepts any parseable datetime string.

.PARAMETER EndDateTime
    Optional. Return only sign-ins on or before this datetime. Accepts any parseable datetime string.

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, CSV, JSON. Defaults to Table.

.PARAMETER ShowFailuresOnly
    If specified, adds an OData filter to return only failed sign-in attempts (errorCode ne 0).

.EXAMPLE
    .\msgraph-get-entra-sign-in-logs.ps1 -Top 50 -ShowFailuresOnly
    Retrieves the 50 most recent failed sign-in attempts and displays them in table format.

.EXAMPLE
    .\msgraph-get-entra-sign-in-logs.ps1 -Filter "userPrincipalName eq 'user@contoso.com'" -StartDateTime "2026-01-01" -EndDateTime "2026-03-31" -OutputFormat CSV
    Exports sign-in logs for a specific user within a date range to a timestamped CSV file.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft Graph connection (pre-established by XOAP)
    Permissions: AuditLog.Read.All (Application), Directory.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/signin-list

.COMPONENT
    Microsoft Graph Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of sign-in log entries to return")]
    [ValidateRange(1, 1000)]
    [int]$Top = 100,

    [Parameter(Mandatory = $false, HelpMessage = "OData filter string to narrow results")]
    [string]$Filter,

    [Parameter(Mandatory = $false, HelpMessage = "Return sign-ins on or after this datetime")]
    [string]$StartDateTime,

    [Parameter(Mandatory = $false, HelpMessage = "Return sign-ins on or before this datetime")]
    [string]$EndDateTime,

    [Parameter(Mandatory = $false, HelpMessage = "Output format for results")]
    [ValidateSet('Table', 'CSV', 'JSON')]
    [string]$OutputFormat = 'Table',

    [Parameter(Mandatory = $false, HelpMessage = "Return only failed sign-in attempts")]
    [switch]$ShowFailuresOnly
)

$ErrorActionPreference = 'Stop'

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "🔐 Entra ID Sign-In Log Retrieval" -ForegroundColor Blue
    Write-Host "===================================" -ForegroundColor Blue

    $filterParts = @()

    if ($ShowFailuresOnly) {
        Write-Host "🔍 Filtering for failed sign-ins only" -ForegroundColor Cyan
        $filterParts += "status/errorCode ne 0"
    }

    if ($StartDateTime) {
        $startIso = ([datetime]$StartDateTime).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $filterParts += "createdDateTime ge $startIso"
        Write-Host "🔍 Start date: $startIso" -ForegroundColor Cyan
    }

    if ($EndDateTime) {
        $endIso = ([datetime]$EndDateTime).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $filterParts += "createdDateTime le $endIso"
        Write-Host "🔍 End date:   $endIso" -ForegroundColor Cyan
    }

    if ($Filter) {
        $filterParts += $Filter
        Write-Host "🔍 Custom filter: $Filter" -ForegroundColor Cyan
    }

    $select = "id,createdDateTime,userDisplayName,userPrincipalName,appDisplayName,ipAddress,clientAppUsed,deviceDetail,location,status,conditionalAccessStatus"
    $uri = "$GraphBase/auditLogs/signIns?`$top=$Top&`$select=$select"

    if ($filterParts.Count -gt 0) {
        $combined = $filterParts -join " and "
        $uri += "&`$filter=$([Uri]::EscapeDataString($combined))"
    }

    Write-Host "🔄 Retrieving sign-in logs from Microsoft Graph..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET

    $logs = [System.Collections.Generic.List[PSObject]]::new()
    $logs.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink -and $logs.Count -lt $Top) {
        Write-Host "   ↳ Fetching next page..." -ForegroundColor Gray
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $logs.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    if ($logs.Count -eq 0) {
        Write-Host "ℹ️  No sign-in logs found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "✅ Retrieved $($logs.Count) sign-in log entr$(if ($logs.Count -eq 1) { 'y' } else { 'ies' })" -ForegroundColor Green

    switch ($OutputFormat) {
        'Table' {
            $logs | Select-Object `
                @{N='Date'; E={ $_.createdDateTime }},
                @{N='User'; E={ $_.userPrincipalName }},
                @{N='App'; E={ $_.appDisplayName }},
                @{N='IP'; E={ $_.ipAddress }},
                @{N='Client'; E={ $_.clientAppUsed }},
                @{N='Result'; E={ if ($_.status.errorCode -eq 0) { 'Success' } else { "Failure ($($_.status.errorCode))" } }} |
                Format-Table -AutoSize
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "entra-sign-in-logs-$timestamp.csv"
            $logs | Select-Object id, createdDateTime, userDisplayName, userPrincipalName,
                appDisplayName, ipAddress, clientAppUsed,
                @{N='errorCode'; E={ $_.status.errorCode }},
                @{N='failureReason'; E={ $_.status.failureReason }},
                @{N='city'; E={ $_.location.city }},
                @{N='countryOrRegion'; E={ $_.location.countryOrRegion }} |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported $($logs.Count) entries to: $filePath" -ForegroundColor Green
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "entra-sign-in-logs-$timestamp.json"
            $logs | ConvertTo-Json -Depth 8 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported $($logs.Count) entries to: $filePath" -ForegroundColor Green
        }
    }

    Write-Host "`n📊 Summary: $($logs.Count) sign-in log entr$(if ($logs.Count -eq 1) { 'y' } else { 'ies' }) returned" -ForegroundColor Blue
    $successCount = ($logs | Where-Object { $_.status.errorCode -eq 0 }).Count
    $failCount    = ($logs | Where-Object { $_.status.errorCode -ne 0 }).Count
    Write-Host "   Successful sign-ins: $successCount" -ForegroundColor Green
    Write-Host "   Failed sign-ins:     $failCount" -ForegroundColor $(if ($failCount -gt 0) { 'Red' } else { 'White' })
}
catch {
    Write-Host "❌ Failed to retrieve sign-in logs: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
