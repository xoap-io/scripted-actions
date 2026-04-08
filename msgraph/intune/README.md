# Microsoft Intune Management Scripts

This directory contains PowerShell scripts for managing Microsoft Intune resources via the
Microsoft Graph API, including managed devices, applications, compliance policies, and
configuration profiles.

## Prerequisites

- Microsoft Graph PowerShell SDK (`Microsoft.Graph` module)
- App Registration with the following permissions (granted by XOAP):
  - `DeviceManagementManagedDevices.ReadWrite.All`
  - `DeviceManagementApps.ReadWrite.All`
  - `DeviceManagementConfiguration.ReadWrite.All`
  - `DeviceManagementRBAC.Read.All`

## Scripts

| Script | Description |
|---|---|
| [`msgraph-get-intune-managed-devices.ps1`](./msgraph-get-intune-managed-devices.ps1) | List and filter managed devices |
| [`msgraph-get-intune-device-compliance.ps1`](./msgraph-get-intune-device-compliance.ps1) | Get device compliance status and policies |
| [`msgraph-sync-intune-device.ps1`](./msgraph-sync-intune-device.ps1) | Trigger a sync on one or more managed devices |
| [`msgraph-get-intune-apps.ps1`](./msgraph-get-intune-apps.ps1) | List managed and published Intune apps |
| [`msgraph-assign-intune-app.ps1`](./msgraph-assign-intune-app.ps1) | Assign an Intune app to a group |
| [`msgraph-get-intune-config-policies.ps1`](./msgraph-get-intune-config-policies.ps1) | List device configuration profiles and policies |

## Quick Start

```powershell
# List all managed devices
.\msgraph-get-intune-managed-devices.ps1

# Filter devices by OS
.\msgraph-get-intune-managed-devices.ps1 -OperatingSystem Windows

# Check compliance status
.\msgraph-get-intune-device-compliance.ps1 -ComplianceState noncompliant

# Sync a specific device
.\msgraph-sync-intune-device.ps1 -DeviceId "00000000-0000-0000-0000-000000000000"

# List all published apps
.\msgraph-get-intune-apps.ps1

# Assign an app to a group
.\msgraph-assign-intune-app.ps1 -AppId "00000000-0000-0000-0000-000000000000" -GroupId "11111111-1111-1111-1111-111111111111" -Intent required

# List configuration policies
.\msgraph-get-intune-config-policies.ps1 -Platform windows10
```
