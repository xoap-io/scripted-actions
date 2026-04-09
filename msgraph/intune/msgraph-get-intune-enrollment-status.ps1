<#
.SYNOPSIS
    Report on Intune device enrollment status by platform and ownership type.

.DESCRIPTION
    This script retrieves Microsoft Intune managed device enrollment data using the Microsoft
    Graph API and produces a grouped enrollment status report. Supports filtering by platform
    and enrollment type, with Summary, Table, CSV, and JSON output formats.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint:
      GET /deviceManagement/managedDevices

.PARAMETER Platform
    Filter devices by operating system. Valid values: All, Windows, iOS, Android, macOS.
    Defaults to All.

.PARAMETER EnrollmentType
    Filter by device ownership / enrollment category. Valid values: All, Corporate, Personal.
    Defaults to All.

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, Summary, CSV, JSON.
    - Summary: grouped counts by platform, ownership type, and compliance state.
    - Table: per-device rows.
    Defaults to Summary.

.EXAMPLE
    .\msgraph-get-intune-enrollment-status.ps1
    Displays a summary of all enrolled devices grouped by platform and enrollment type.

.EXAMPLE
    .\msgraph-get-intune-enrollment-status.ps1 -Platform Windows -EnrollmentType Corporate -OutputFormat CSV
    Exports all corporate-enrolled Windows devices to a timestamped CSV file.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft Graph connection (pre-established by XOAP)
    Permissions: DeviceManagementManagedDevices.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-list

.COMPONENT
    Microsoft Graph Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Filter devices by operating system platform")]
    [ValidateSet('All', 'Windows', 'iOS', 'Android', 'macOS')]
    [string]$Platform = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by device ownership type")]
    [ValidateSet('All', 'Corporate', 'Personal')]
    [string]$EnrollmentType = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Output format: Summary, Table, CSV, or JSON")]
    [ValidateSet('Table', 'Summary', 'CSV', 'JSON')]
    [string]$OutputFormat = 'Summary'
)

$ErrorActionPreference = 'Stop'

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "📋 Intune Enrollment Status Report" -ForegroundColor Blue
    Write-Host "====================================" -ForegroundColor Blue

    $select = "id,deviceName,operatingSystem,osVersion,complianceState,managedDeviceOwnerType,userPrincipalName,enrolledDateTime,lastSyncDateTime,enrollmentType"
    $filterParts = @()

    if ($Platform -ne 'All')        { $filterParts += "operatingSystem eq '$Platform'" }
    if ($EnrollmentType -ne 'All')  { $filterParts += "managedDeviceOwnerType eq '$($EnrollmentType.ToLower())'" }

    $uri = "$GraphBase/deviceManagement/managedDevices?`$top=999&`$select=$select"
    if ($filterParts.Count -gt 0) {
        $combined = $filterParts -join " and "
        Write-Host "🔍 Applying filter: $combined" -ForegroundColor Cyan
        $uri += "&`$filter=$([Uri]::EscapeDataString($combined))"
    }

    Write-Host "🔄 Retrieving enrollment data from Microsoft Graph..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET

    $devices = [System.Collections.Generic.List[PSObject]]::new()
    $devices.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink) {
        Write-Host "   ↳ Fetching next page..." -ForegroundColor Gray
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $devices.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    if ($devices.Count -eq 0) {
        Write-Host "ℹ️  No enrolled devices found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "✅ Retrieved $($devices.Count) enrolled device(s)" -ForegroundColor Green

    switch ($OutputFormat) {
        'Summary' {
            Write-Host "`n📊 Enrollment Summary:" -ForegroundColor Blue
            Write-Host "   Total Enrolled: $($devices.Count)" -ForegroundColor White

            Write-Host "`n   By Platform:" -ForegroundColor Cyan
            $devices | Group-Object operatingSystem | Sort-Object Count -Descending | ForEach-Object {
                Write-Host "     $($_.Name): $($_.Count)" -ForegroundColor White
            }

            Write-Host "`n   By Ownership:" -ForegroundColor Cyan
            $devices | Group-Object managedDeviceOwnerType | Sort-Object Count -Descending | ForEach-Object {
                Write-Host "     $($_.Name): $($_.Count)" -ForegroundColor White
            }

            Write-Host "`n   By Compliance State:" -ForegroundColor Cyan
            $devices | Group-Object complianceState | Sort-Object Count -Descending | ForEach-Object {
                $color = switch ($_.Name) { 'compliant' { 'Green' } 'noncompliant' { 'Red' } default { 'Yellow' } }
                Write-Host "     $($_.Name): $($_.Count)" -ForegroundColor $color
            }
        }
        'Table' {
            $devices | Select-Object deviceName, operatingSystem, osVersion, complianceState,
                @{N='OwnerType'; E={ $_.managedDeviceOwnerType }},
                @{N='User'; E={ $_.userPrincipalName }},
                @{N='Enrolled'; E={ $_.enrolledDateTime }},
                @{N='Last Sync'; E={ $_.lastSyncDateTime }} |
                Format-Table -AutoSize
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-enrollment-status-$timestamp.csv"
            $devices | Select-Object id, deviceName, operatingSystem, osVersion, complianceState,
                managedDeviceOwnerType, userPrincipalName, enrolledDateTime, lastSyncDateTime, enrollmentType |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported $($devices.Count) devices to: $filePath" -ForegroundColor Green
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-enrollment-status-$timestamp.json"
            $devices | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported $($devices.Count) devices to: $filePath" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "❌ Failed to retrieve enrollment status: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
