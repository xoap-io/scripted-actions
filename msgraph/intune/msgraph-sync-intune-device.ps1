<#
.SYNOPSIS
    Trigger a sync on one or more Microsoft Intune managed devices via the Microsoft Graph API.

.DESCRIPTION
    This script sends a sync command to one or more Microsoft Intune managed devices using
    the Microsoft Graph API. The sync command instructs the device to check in with Intune
    and apply any pending policies or configurations.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint:
    POST /deviceManagement/managedDevices/{id}/syncDevice

.PARAMETER DeviceId
    Object ID of the specific managed device to sync.

.PARAMETER DeviceName
    Name of the managed device to sync. Looked up via Graph API.

.PARAMETER UserPrincipalName
    Sync all devices enrolled by the specified user UPN.

.PARAMETER All
    Sync all managed devices. Use with caution in large environments.

.PARAMETER OperatingSystem
    When using -All, filter devices by OS before syncing.
    Valid values: Windows, iOS, Android, macOS.

.EXAMPLE
    .\msgraph-sync-intune-device.ps1 -DeviceId "00000000-0000-0000-0000-000000000000"
    Syncs a specific device by ID.

.EXAMPLE
    .\msgraph-sync-intune-device.ps1 -DeviceName "DESKTOP-ABC123"
    Looks up and syncs a device by name.

.EXAMPLE
    .\msgraph-sync-intune-device.ps1 -UserPrincipalName "user@contoso.com"
    Syncs all devices enrolled by the specified user.

.EXAMPLE
    .\msgraph-sync-intune-device.ps1 -All -OperatingSystem Windows
    Syncs all Windows managed devices.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: DeviceManagementManagedDevices.ReadWrite.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-devices-manageddevice-syncdevice

.COMPONENT
    Microsoft Graph, Microsoft Intune
#>

[CmdletBinding(DefaultParameterSetName = 'ByDeviceId')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'ByDeviceId', HelpMessage = "Object ID of the managed device")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$DeviceId,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByDeviceName', HelpMessage = "Name of the managed device")]
    [ValidateNotNullOrEmpty()]
    [string]$DeviceName,

    [Parameter(Mandatory = $true, ParameterSetName = 'ByUser', HelpMessage = "UPN of the user whose devices to sync")]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $true, ParameterSetName = 'All', HelpMessage = "Sync all managed devices")]
    [switch]$All,

    [Parameter(Mandatory = $false, ParameterSetName = 'All', HelpMessage = "Filter by OS when syncing all devices")]
    [ValidateSet('Windows', 'iOS', 'Android', 'macOS')]
    [string]$OperatingSystem
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

function Invoke-DeviceSync {
    param(
        [PSObject]$Device
    )

    try {
        Write-Host "   🔄 Syncing: $($Device.deviceName) ($($Device.operatingSystem))..." -ForegroundColor Cyan
        Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$($Device.id)/syncDevice" -Method POST
        Write-Host "   ✅ Sync initiated for: $($Device.deviceName)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "   ❌ Failed to sync: $($Device.deviceName) — $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

try {
    Write-Host "🔄 Intune Device Sync" -ForegroundColor Blue
    Write-Host "=====================" -ForegroundColor Blue

    $devicesToSync = @()

    switch ($PSCmdlet.ParameterSetName) {
        'ByDeviceId' {
            Write-Host "🔍 Looking up device: $DeviceId..." -ForegroundColor Cyan
            $device = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$DeviceId`?`$select=id,deviceName,operatingSystem,userPrincipalName" -Method GET
            $devicesToSync += $device
        }
        'ByDeviceName' {
            Write-Host "🔍 Looking up device by name: $DeviceName..." -ForegroundColor Cyan
            $filter = [Uri]::EscapeDataString("deviceName eq '$DeviceName'")
            $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$filter&`$select=id,deviceName,operatingSystem,userPrincipalName" -Method GET
            if ($response.value.Count -eq 0) {
                Write-Host "❌ No device found with name '$DeviceName'" -ForegroundColor Red
                exit 1
            }
            $devicesToSync += $response.value
        }
        'ByUser' {
            Write-Host "🔍 Looking up devices for user: $UserPrincipalName..." -ForegroundColor Cyan
            $filter = [Uri]::EscapeDataString("userPrincipalName eq '$UserPrincipalName'")
            $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=$filter&`$select=id,deviceName,operatingSystem,userPrincipalName" -Method GET
            if ($response.value.Count -eq 0) {
                Write-Host "ℹ️  No devices found for user '$UserPrincipalName'" -ForegroundColor Yellow
                exit 0
            }
            $devicesToSync += $response.value
        }
        'All' {
            Write-Host "⚠️  Syncing all managed devices. This may take several minutes." -ForegroundColor Yellow
            $uri = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem,userPrincipalName"
            if ($OperatingSystem) {
                $filter = [Uri]::EscapeDataString("operatingSystem eq '$OperatingSystem'")
                $uri += "&`$filter=$filter"
                Write-Host "🔍 Filtering by OS: $OperatingSystem" -ForegroundColor Cyan
            }
            $response = Invoke-MgGraphRequest -Uri $uri -Method GET
            $allDevices = [System.Collections.Generic.List[PSObject]]::new()
            $allDevices.AddRange([PSObject[]]$response.value)
            $nextLink = $response.'@odata.nextLink'
            while ($nextLink) {
                $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
                $allDevices.AddRange([PSObject[]]$pageResponse.value)
                $nextLink = $pageResponse.'@odata.nextLink'
            }
            $devicesToSync = $allDevices

            $confirm = Read-Host "About to sync $($devicesToSync.Count) device(s). Type 'YES' to confirm"
            if ($confirm -ne 'YES') {
                Write-Host "❌ Operation cancelled." -ForegroundColor Yellow
                exit 0
            }
        }
    }

    Write-Host "📱 Syncing $($devicesToSync.Count) device(s)..." -ForegroundColor Cyan
    Write-Host ""

    $successCount = 0
    $failCount = 0

    foreach ($device in $devicesToSync) {
        $result = Invoke-DeviceSync -Device $device
        if ($result) { $successCount++ } else { $failCount++ }
    }

    Write-Host "`n📊 Sync Summary:" -ForegroundColor Blue
    Write-Host "   Successful: $successCount" -ForegroundColor Green
    if ($failCount -gt 0) {
        Write-Host "   Failed:     $failCount" -ForegroundColor Red
    }
    Write-Host "`n💡 Note: Device sync may take a few minutes to complete." -ForegroundColor Yellow
}
catch {
    Write-Host "❌ Failed to sync device(s): $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
