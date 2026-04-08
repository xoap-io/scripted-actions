<#
.SYNOPSIS
    Get Microsoft Intune device compliance status and policies via the Microsoft Graph API.

.DESCRIPTION
    This script retrieves device compliance status and associated compliance policies from
    Microsoft Intune using the Microsoft Graph API. Can report on device-level compliance
    state or list available compliance policies.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoints:
    - GET /deviceManagement/managedDevices
    - GET /deviceManagement/deviceCompliancePolicies

.PARAMETER Mode
    Operating mode. DeviceStatus lists devices with compliance state.
    Policies lists available compliance policies.
    Valid values: DeviceStatus, Policies.

.PARAMETER ComplianceState
    Filter devices by compliance state (DeviceStatus mode only).
    Valid values: All, compliant, noncompliant, unknown, notApplicable, inGracePeriod, error.

.PARAMETER OperatingSystem
    Filter devices by OS (DeviceStatus mode only).
    Valid values: All, Windows, iOS, Android, macOS.

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, List, JSON, CSV.

.EXAMPLE
    .\msgraph-get-intune-device-compliance.ps1 -Mode DeviceStatus
    Lists compliance status for all managed devices.

.EXAMPLE
    .\msgraph-get-intune-device-compliance.ps1 -Mode DeviceStatus -ComplianceState noncompliant -OutputFormat CSV
    Exports all non-compliant devices to a CSV report in the current directory.

.EXAMPLE
    .\msgraph-get-intune-device-compliance.ps1 -Mode Policies -OutputFormat Table
    Lists all configured compliance policies.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: DeviceManagementManagedDevices.Read.All (Application),
                          DeviceManagementConfiguration.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-devicecompliancepolicy-list

.COMPONENT
    Microsoft Graph, Microsoft Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Operating mode")]
    [ValidateSet('DeviceStatus', 'Policies')]
    [string]$Mode = 'DeviceStatus',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by compliance state (DeviceStatus mode)")]
    [ValidateSet('All', 'compliant', 'noncompliant', 'unknown', 'notApplicable', 'inGracePeriod', 'error')]
    [string]$ComplianceState = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by operating system (DeviceStatus mode)")]
    [ValidateSet('All', 'Windows', 'iOS', 'Android', 'macOS')]
    [string]$OperatingSystem = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'List', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

function Get-DeviceComplianceStatus {
    Write-Host "📋 Device Compliance Status" -ForegroundColor Blue
    Write-Host "===========================" -ForegroundColor Blue

    $select = "id,deviceName,operatingSystem,osVersion,complianceState,userPrincipalName,lastSyncDateTime,deviceType"
    $filterParts = @()
    if ($ComplianceState -ne 'All') { $filterParts += "complianceState eq '$ComplianceState'" }
    if ($OperatingSystem -ne 'All') { $filterParts += "operatingSystem eq '$OperatingSystem'" }

    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=$select"
    if ($filterParts.Count -gt 0) {
        $combined = $filterParts -join " and "
        Write-Host "🔍 Applying filter: $combined" -ForegroundColor Cyan
        $uri += "&`$filter=$([Uri]::EscapeDataString($combined))"
    }

    Write-Host "🔄 Retrieving compliance data from Microsoft Graph..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET
    $devices = [System.Collections.Generic.List[PSObject]]::new()
    $devices.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink) {
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $devices.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    if ($devices.Count -eq 0) {
        Write-Host "ℹ️  No devices found matching the specified criteria." -ForegroundColor Yellow
        return
    }

    Write-Host "✅ Retrieved $($devices.Count) device(s)" -ForegroundColor Green

    switch ($OutputFormat) {
        'Table' {
            $devices | Select-Object deviceName, operatingSystem, complianceState,
                @{N='User'; E={ $_.userPrincipalName }},
                @{N='Last Sync'; E={ $_.lastSyncDateTime }} |
                Format-Table -AutoSize
        }
        'List' {
            foreach ($device in $devices) {
                $color = switch ($device.complianceState) {
                    'compliant'    { 'Green' }
                    'noncompliant' { 'Red' }
                    default        { 'Yellow' }
                }
                Write-Host "`n💻 $($device.deviceName)" -ForegroundColor Yellow
                Write-Host "   Compliance:  $($device.complianceState)" -ForegroundColor $color
                Write-Host "   OS:          $($device.operatingSystem) $($device.osVersion)" -ForegroundColor White
                Write-Host "   User:        $($device.userPrincipalName)" -ForegroundColor White
                Write-Host "   Last Sync:   $($device.lastSyncDateTime)" -ForegroundColor White
            }
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-compliance-status-$timestamp.json"
            $devices | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported to: $filePath" -ForegroundColor Green
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-compliance-status-$timestamp.csv"
            $devices | Select-Object id, deviceName, operatingSystem, osVersion, complianceState,
                userPrincipalName, lastSyncDateTime |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported to: $filePath" -ForegroundColor Green
        }
    }

    # Compliance summary
    Write-Host "`n📊 Compliance Summary:" -ForegroundColor Blue
    $devices | Group-Object complianceState | Sort-Object Name | ForEach-Object {
        $color = switch ($_.Name) { 'compliant' { 'Green' } 'noncompliant' { 'Red' } default { 'Yellow' } }
        $pct = [math]::Round(($_.Count / $devices.Count) * 100, 1)
        Write-Host "   $($_.Name): $($_.Count) ($pct%)" -ForegroundColor $color
    }
}

function Get-CompliancePolicies {
    Write-Host "📋 Intune Compliance Policies" -ForegroundColor Blue
    Write-Host "==============================" -ForegroundColor Blue

    Write-Host "🔄 Retrieving compliance policies from Microsoft Graph..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies" -Method GET

    $policies = [System.Collections.Generic.List[PSObject]]::new()
    $policies.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink) {
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $policies.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    if ($policies.Count -eq 0) {
        Write-Host "ℹ️  No compliance policies found." -ForegroundColor Yellow
        return
    }

    Write-Host "✅ Retrieved $($policies.Count) policy/policies" -ForegroundColor Green

    switch ($OutputFormat) {
        'Table' {
            $policies | Select-Object displayName,
                @{N='Platform'; E={ $_.'@odata.type' -replace '#microsoft.graph.','' -replace 'CompliancePolicy','' }},
                @{N='Created'; E={ $_.createdDateTime }},
                @{N='Modified'; E={ $_.lastModifiedDateTime }} |
                Format-Table -AutoSize
        }
        'List' {
            foreach ($policy in $policies) {
                $platform = $policy.'@odata.type' -replace '#microsoft.graph.','' -replace 'CompliancePolicy',''
                Write-Host "`n📋 $($policy.displayName)" -ForegroundColor Yellow
                Write-Host "   ID:       $($policy.id)" -ForegroundColor White
                Write-Host "   Platform: $platform" -ForegroundColor White
                Write-Host "   Created:  $($policy.createdDateTime)" -ForegroundColor White
                Write-Host "   Modified: $($policy.lastModifiedDateTime)" -ForegroundColor White
                if ($policy.description) {
                    Write-Host "   Desc:     $($policy.description)" -ForegroundColor White
                }
            }
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-compliance-policies-$timestamp.json"
            $policies | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported to: $filePath" -ForegroundColor Green
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-compliance-policies-$timestamp.csv"
            $policies | Select-Object id, displayName,
                @{N='Platform'; E={ $_.'@odata.type' }},
                description, createdDateTime, lastModifiedDateTime |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported to: $filePath" -ForegroundColor Green
        }
    }
}

try {
    switch ($Mode) {
        'DeviceStatus' { Get-DeviceComplianceStatus }
        'Policies'     { Get-CompliancePolicies }
    }
}
catch {
    Write-Host "❌ Failed to retrieve compliance data: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
