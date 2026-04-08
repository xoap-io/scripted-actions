<#
.SYNOPSIS
    List and filter Microsoft Intune managed devices via the Microsoft Graph API.

.DESCRIPTION
    This script retrieves managed devices enrolled in Microsoft Intune using the Microsoft
    Graph API. Supports filtering by OS, compliance state, and device ownership, with
    multiple output format options.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: GET /deviceManagement/managedDevices

.PARAMETER OperatingSystem
    Filter devices by operating system. Valid values: All, Windows, iOS, Android, macOS.

.PARAMETER ComplianceState
    Filter devices by compliance state. Valid values: All, compliant, noncompliant, unknown, notApplicable.

.PARAMETER OwnerType
    Filter by device ownership. Valid values: All, company, personal.

.PARAMETER Filter
    Additional OData filter expression to apply.

.PARAMETER Top
    Maximum number of devices to return. Defaults to 100.

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, List, JSON, CSV.

.EXAMPLE
    .\msgraph-get-intune-managed-devices.ps1
    Lists all managed devices.

.EXAMPLE
    .\msgraph-get-intune-managed-devices.ps1 -OperatingSystem Windows -ComplianceState noncompliant
    Lists all non-compliant Windows devices.

.EXAMPLE
    .\msgraph-get-intune-managed-devices.ps1 -OwnerType company -OutputFormat CSV
    Exports all company-owned devices to a CSV report in the current directory.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: DeviceManagementManagedDevices.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-list

.COMPONENT
    Microsoft Graph, Microsoft Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Filter by operating system")]
    [ValidateSet('All', 'Windows', 'iOS', 'Android', 'macOS')]
    [string]$OperatingSystem = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by compliance state")]
    [ValidateSet('All', 'compliant', 'noncompliant', 'unknown', 'notApplicable')]
    [string]$ComplianceState = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by device ownership")]
    [ValidateSet('All', 'company', 'personal')]
    [string]$OwnerType = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Additional OData filter expression")]
    [string]$Filter,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of results to return")]
    [ValidateRange(1, 999)]
    [int]$Top = 100,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'List', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    Write-Host "📱 Intune Managed Device Listing" -ForegroundColor Blue
    Write-Host "=================================" -ForegroundColor Blue

    $select = "id,deviceName,operatingSystem,osVersion,complianceState,managedDeviceOwnerType,userPrincipalName,lastSyncDateTime,enrolledDateTime,manufacturer,model,serialNumber"

    $filterParts = @()
    if ($OperatingSystem -ne 'All') { $filterParts += "operatingSystem eq '$OperatingSystem'" }
    if ($ComplianceState -ne 'All') { $filterParts += "complianceState eq '$ComplianceState'" }
    if ($OwnerType -ne 'All')       { $filterParts += "managedDeviceOwnerType eq '$OwnerType'" }
    if ($Filter)                    { $filterParts += $Filter }

    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$top=$Top&`$select=$select"
    if ($filterParts.Count -gt 0) {
        $combined = $filterParts -join " and "
        Write-Host "🔍 Applying filter: $combined" -ForegroundColor Cyan
        $uri += "&`$filter=$([Uri]::EscapeDataString($combined))"
    }

    Write-Host "🔄 Retrieving managed devices from Microsoft Graph..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET

    $devices = [System.Collections.Generic.List[PSObject]]::new()
    $devices.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink -and $devices.Count -lt $Top) {
        Write-Host "   ↳ Fetching next page..." -ForegroundColor Gray
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $devices.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    if ($devices.Count -eq 0) {
        Write-Host "ℹ️  No managed devices found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "✅ Retrieved $($devices.Count) device(s)" -ForegroundColor Green

    switch ($OutputFormat) {
        'Table' {
            $devices | Select-Object deviceName, operatingSystem, osVersion, complianceState,
                @{N='Owner'; E={ $_.managedDeviceOwnerType }},
                @{N='User'; E={ $_.userPrincipalName }},
                @{N='Last Sync'; E={ $_.lastSyncDateTime }} |
                Format-Table -AutoSize
        }
        'List' {
            foreach ($device in $devices) {
                $complianceColor = switch ($device.complianceState) {
                    'compliant'     { 'Green' }
                    'noncompliant'  { 'Red' }
                    default         { 'Yellow' }
                }
                Write-Host "`n💻 $($device.deviceName)" -ForegroundColor Yellow
                Write-Host "   Device ID:     $($device.id)" -ForegroundColor White
                Write-Host "   OS:            $($device.operatingSystem) $($device.osVersion)" -ForegroundColor White
                Write-Host "   Compliance:    $($device.complianceState)" -ForegroundColor $complianceColor
                Write-Host "   Owner Type:    $($device.managedDeviceOwnerType)" -ForegroundColor White
                Write-Host "   User:          $($device.userPrincipalName)" -ForegroundColor White
                Write-Host "   Manufacturer:  $($device.manufacturer)" -ForegroundColor White
                Write-Host "   Model:         $($device.model)" -ForegroundColor White
                Write-Host "   Serial:        $($device.serialNumber)" -ForegroundColor White
                Write-Host "   Last Sync:     $($device.lastSyncDateTime)" -ForegroundColor White
                Write-Host "   Enrolled:      $($device.enrolledDateTime)" -ForegroundColor White
            }
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-devices-$timestamp.json"
            $devices | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported $($devices.Count) devices to: $filePath" -ForegroundColor Green
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-devices-$timestamp.csv"
            $devices | Select-Object id, deviceName, operatingSystem, osVersion, complianceState,
                managedDeviceOwnerType, userPrincipalName, manufacturer, model, serialNumber,
                lastSyncDateTime, enrolledDateTime |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported $($devices.Count) devices to: $filePath" -ForegroundColor Green
        }
    }

    # Summary by compliance state
    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "   Total Devices:  $($devices.Count)" -ForegroundColor White
    $devices | Group-Object complianceState | ForEach-Object {
        $color = switch ($_.Name) { 'compliant' { 'Green' } 'noncompliant' { 'Red' } default { 'Yellow' } }
        Write-Host "   $($_.Name): $($_.Count)" -ForegroundColor $color
    }
}
catch {
    Write-Host "❌ Failed to retrieve managed devices: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
