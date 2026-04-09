<#
.SYNOPSIS
    Retire or wipe a managed Intune device via the Microsoft Graph API.

.DESCRIPTION
    This script retires or wipes a managed device in Microsoft Intune using the Microsoft
    Graph API. Retire removes corporate data while preserving personal data. Wipe performs
    a full factory reset. The device can be identified by name or Device ID.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoints:
      GET /deviceManagement/managedDevices
      POST /deviceManagement/managedDevices/{id}/retire
      POST /deviceManagement/managedDevices/{id}/wipe

.PARAMETER DeviceNameOrId
    The device name or managed Device ID (GUID) to target.

.PARAMETER Action
    The action to perform. Valid values: Retire, Wipe. Defaults to Retire.
    - Retire: Removes corporate data, preserves personal data and apps.
    - Wipe: Full factory reset; all data is erased.

.PARAMETER Force
    Skip the confirmation prompt before performing the action.

.PARAMETER WhatIf
    Display what would happen without actually performing the action.

.EXAMPLE
    .\msgraph-retire-intune-device.ps1 -DeviceNameOrId "DESKTOP-ABC1234" -Action Retire
    Retires the specified device after showing device details and prompting for confirmation.

.EXAMPLE
    .\msgraph-retire-intune-device.ps1 -DeviceNameOrId "00000000-0000-0000-0000-000000000000" -Action Wipe -Force
    Performs a full wipe on the device identified by its managed Device ID without confirmation.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft Graph connection (pre-established by XOAP)
    Permissions: DeviceManagementManagedDevices.PrivilegedOperations.All (Application), DeviceManagementManagedDevices.ReadWrite.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-retire

.COMPONENT
    Microsoft Graph Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The device name or managed Device ID (GUID)")]
    [ValidateNotNullOrEmpty()]
    [string]$DeviceNameOrId,

    [Parameter(Mandatory = $false, HelpMessage = "The action to perform: Retire (remove corporate data) or Wipe (factory reset)")]
    [ValidateSet('Retire', 'Wipe')]
    [string]$Action = 'Retire',

    [Parameter(Mandatory = $false, HelpMessage = "Skip the confirmation prompt")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Show what would happen without performing the action")]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "📱 Intune Device $Action" -ForegroundColor Blue
    Write-Host "========================" -ForegroundColor Blue

    # Resolve device — try direct ID lookup first, then search by name
    Write-Host "🔍 Resolving device: $DeviceNameOrId..." -ForegroundColor Cyan
    $isGuid = $DeviceNameOrId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $select = "id,deviceName,operatingSystem,osVersion,complianceState,managedDeviceOwnerType,userPrincipalName,userDisplayName,enrolledDateTime,lastSyncDateTime"

    if ($isGuid) {
        $device = Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/managedDevices/$DeviceNameOrId`?`$select=$select" -Method GET
    }
    else {
        $devResponse = Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/managedDevices?`$filter=deviceName eq '$([Uri]::EscapeDataString($DeviceNameOrId))'&`$select=$select" -Method GET
        $device = $devResponse.value | Select-Object -First 1
        if (-not $device) {
            Write-Host "❌ No managed device found with name: $DeviceNameOrId" -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "✅ Found device: $($device.deviceName)" -ForegroundColor Green
    Write-Host "`n📊 Device Details:" -ForegroundColor Blue
    Write-Host "   Device Name:    $($device.deviceName)" -ForegroundColor White
    Write-Host "   Device ID:      $($device.id)" -ForegroundColor White
    Write-Host "   OS:             $($device.operatingSystem) $($device.osVersion)" -ForegroundColor White
    Write-Host "   Owner:          $($device.userDisplayName) ($($device.userPrincipalName))" -ForegroundColor White
    Write-Host "   Owner Type:     $($device.managedDeviceOwnerType)" -ForegroundColor White
    Write-Host "   Compliance:     $($device.complianceState)" -ForegroundColor $(switch ($device.complianceState) { 'compliant' { 'Green' } 'noncompliant' { 'Red' } default { 'Yellow' } })
    Write-Host "   Last Sync:      $($device.lastSyncDateTime)" -ForegroundColor White

    if ($Action -eq 'Wipe') {
        Write-Host "`n⚠️  WARNING: Wipe will perform a FULL FACTORY RESET. All data will be erased." -ForegroundColor Red
    }
    else {
        Write-Host "`nℹ️  Retire will remove corporate data and unenroll the device. Personal data is preserved." -ForegroundColor Yellow
    }

    # WhatIf mode
    if ($WhatIf) {
        Write-Host "`n🔍 WhatIf: Would perform '$Action' on device '$($device.deviceName)' (Id: $($device.id))" -ForegroundColor Cyan
        exit 0
    }

    # Confirmation prompt
    if (-not $Force) {
        $confirmation = Read-Host "`nType 'YES' to confirm $Action on '$($device.deviceName)' or anything else to cancel"
        if ($confirmation -ne 'YES') {
            Write-Host "❌ Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Perform action
    Write-Host "`n🔧 Performing $Action on $($device.deviceName)..." -ForegroundColor Cyan
    $actionEndpoint = $Action.ToLower()
    Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/managedDevices/$($device.id)/$actionEndpoint" -Method POST -Body "{}" -ContentType "application/json"

    Write-Host "✅ $Action command sent successfully to device: $($device.deviceName)" -ForegroundColor Green

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    if ($Action -eq 'Retire') {
        Write-Host "   - The device will be unenrolled once it checks in with Intune" -ForegroundColor White
        Write-Host "   - Corporate apps, email profiles, and VPN/Wi-Fi configs will be removed" -ForegroundColor White
    }
    else {
        Write-Host "   - The device will factory reset on next check-in with Intune" -ForegroundColor White
        Write-Host "   - Ensure the device owner is aware that all data will be lost" -ForegroundColor White
    }
}
catch {
    Write-Host "❌ Failed to $Action device: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
