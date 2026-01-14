# Windows Server 2019 RDS Optimization Scripts

This collection provides comprehensive optimization for Windows Server 2019 in Remote Desktop Services (RDS) environments with multiple users.

## Scripts Overview

### `ws2019-rds-optimization.ps1`

Main optimization script that applies performance and security enhancements for RDS environments.

### `ws2019-rds-optimization-restore.ps1`

Restoration script to selectively reverse optimizations if needed.

## Key Optimizations Applied

### **Enhanced Resource Validation & Dry-Run Features**

- **Pre-Optimization Checks**: Validates all services, tasks, and features before modification
- **Current Value Display**: Shows existing settings in dry-run mode with before/after comparisons
- **Smart Skipping**: Avoids unnecessary changes when settings are already correct
- **Missing Resource Handling**: Gracefully handles non-existent services/tasks with detailed logging
- **Comprehensive Preview**: True dry-run shows exactly what would change with current values

### User Interface & Experience

- **Hide Local Drives**: Prevents users from accessing local drives (C:, D:, etc.)
- **Disable Server Manager**: Stops automatic Server Manager startup
- **Hide Action Center**: Removes Action Center icon and notifications
- **Visual Effects**: Optimizes for performance over appearance
- **Logon Background**: Disables logon background image for faster logon

### Services Management

Disables unnecessary services including:

- AllJoyn Router Service
- Bluetooth Support
- Background Intelligent Transfer Service (BITS)
- Diagnostic services
- Geolocation services
- Windows Update (for controlled environments)
- Xbox services
- Telemetry services

### Performance Optimizations

- **Memory Management**: Keeps drivers/kernel in physical memory
- **Power Plan**: Sets to High Performance
- **Network Optimization**: TCP ACK frequency and Nagle algorithm tuning
- **Search Indexing**: Disabled for better I/O performance
- **Crash Dumps**: Disabled to save space and improve performance

### Security Enhancements

- **USB Storage**: Disabled for regular users
- **Camera Redirection**: Disabled in RDS sessions
- **Machine Account**: Prevents automatic password changes
- **Audit Policy**: Enhanced command line auditing

### RDS-Specific Settings

- **Session Timeouts**: Optimized for persistent connections
- **Keep-Alive**: Enhanced session stability
- **Printer Redirection**: Optimized settings
- **License Server Configuration**: Automatic RDS license server registry setup
- **User Profile Management**: Support for both roaming profiles and User Profile Disks
- **Profile Optimization**: Optimized settings for faster logon/logoff in multi-user environments

## Usage Examples

### Basic Optimization (Default Settings)

```powershell
# Runs with defaults: hides drives and disables Server Manager
.\ws2019-rds-optimization.ps1
```

### Explicit Configuration

```powershell
# Explicitly enable specific optimizations with verbose logging
.\ws2019-rds-optimization.ps1 -HideLocalDrives -DisableServerManager -EnableVerboseLogging
```

### Preview Mode

```powershell
# See what changes would be made without applying them
.\ws2019-rds-optimization.ps1 -DryRun

# Example output:
# [2025-09-03 14:23:45] [INFO] DRY-RUN: Would disable service: BITS (Current: Manual, Status: Stopped)
# [2025-09-03 14:23:46] [INFO] DRY-RUN: Would set registry HKLM:\SOFTWARE\Microsoft\ServerManager\DoNotOpenServerManagerAtLogon = 1 (Current: <not set>) (Disable Server Manager auto-start)
# [2025-09-03 14:23:47] [INFO] DRY-RUN: Would disable scheduled task: \Microsoft\Windows\Defrag\ScheduledDefrag (Current state: Ready)
```

### Enhanced Dry-Run with Resource Validation

```powershell
# Comprehensive preview with verbose resource checking
.\ws2019-rds-optimization.ps1 -DryRun -EnableVerboseLogging

# Shows detailed resource validation:
# Resource validation complete:
#   Services: 38 found, 2 missing
#   Tasks: 35 found, 5 missing
#   Features: 1 found, 0 missing
```

### PVS/MCS Environment with Persistent Drive

```powershell
# Redirect event logs to persistent drive
.\ws2019-rds-optimization.ps1 -PersistentDriveLetter D -EventLogLocation "D:\EventLogs"
```

### Custom Service Management

```powershell
# Disable additional services but keep Windows Update enabled
.\ws2019-rds-optimization.ps1 -DisableServices @('Spooler','Fax') -KeepServices @('wuauserv')
```

### Restoration Examples

```powershell
# Restore drive visibility and Server Manager
.\ws2019-rds-optimization-restore.ps1 -RestoreLocalDrives -RestoreServerManager

# Restore specific services
.\ws2019-rds-optimization-restore.ps1 -RestoreServices @('BITS','wuauserv')

# Restore RDS license server and profile settings
.\ws2019-rds-optimization-restore.ps1 -RestoreRDSSettings
```

### RDS License Server and Profile Management Examples

```powershell
# Configure RDS with license server
.\ws2019-rds-optimization.ps1 -RDSLicenseServer "rds-lic.company.com" -RDSLicenseMode "PerUser"

# Configure with roaming profiles
.\ws2019-rds-optimization.ps1 -UserProfilePath "\\fileserver\profiles$"

# Configure with User Profile Disks
.\ws2019-rds-optimization.ps1 -UserProfileDiskPath "\\fileserver\upd$" -ProfileDiskMaxSizeGB 25

# Complete RDS configuration
.\ws2019-rds-optimization.ps1 -RDSLicenseServer "rds-lic.company.com" -RDSLicenseMode "PerUser" -UserProfileDiskPath "\\fileserver\upd$" -ProfileDiskMaxSizeGB 30
```

## Parameters

### Main Optimization Script

| Parameter               | Type     | Description                                       | Default            |
| ----------------------- | -------- | ------------------------------------------------- | ------------------ |
| `DisableServices`       | String[] | Additional services to disable                    | Empty              |
| `KeepServices`          | String[] | Services to keep enabled (overrides disable list) | Empty              |
| `HideLocalDrives`       | Switch   | Hide local drives from users                      | Enabled by default |
| `DisableServerManager`  | Switch   | Disable Server Manager auto-start                 | Enabled by default |
| `EnableVerboseLogging`  | Switch   | Enable detailed logging                           | Disabled           |
| `PersistentDriveLetter` | String   | Drive letter for persistent storage               | None               |
| `EventLogLocation`      | String   | Custom event log location                         | Default location   |
| `RDSLicenseServer`      | String   | FQDN of RDS License Server                        | None               |
| `RDSLicenseMode`        | String   | RDS licensing mode (PerUser/PerDevice)            | NotConfigured      |
| `UserProfilePath`       | String   | UNC path for roaming profiles                     | None               |
| `UserProfileDiskPath`   | String   | UNC path for User Profile Disks                   | None               |
| `ProfileDiskMaxSizeGB`  | Integer  | Max size in GB for UPD (1-1000)                   | 30                 |
| `DryRun`                | Switch   | Preview changes without applying                  | False              |

### Restoration Script

| Parameter               | Type     | Description                      |
| ----------------------- | -------- | -------------------------------- |
| `RestoreServices`       | String[] | Services to restore              |
| `RestoreLocalDrives`    | Switch   | Restore local drive visibility   |
| `RestoreServerManager`  | Switch   | Re-enable Server Manager         |
| `RestoreScheduledTasks` | String[] | Scheduled tasks to re-enable     |
| `DryRun`                | Switch   | Preview changes without applying |

## Important Notes

### Prerequisites

- Windows Server 2019 (Build 17763 or later)
- PowerShell 5.1 or later
- Administrator privileges
- System backup or snapshot recommended

### Compatibility

- Tested on Windows Server 2019
- Compatible with RDS, VDI, PVS, and MCS environments
- Works with both domain-joined and workgroup servers

### Logging

Both scripts create detailed log files in `%TEMP%` with timestamps for troubleshooting and audit purposes.

### Reboot Recommendations

While not always required, a reboot is recommended after optimization to ensure all changes take effect properly.

## Troubleshooting

### Common Issues

1. **Access Denied**: Ensure running as Administrator
2. **Service Errors**: Some services may already be disabled or not present
3. **Registry Errors**: Certain registry keys may not exist on all systems

### Reverting Changes

Use the restoration script to selectively reverse optimizations:

```powershell
# Preview what would be restored
.\ws2019-rds-optimization-restore.ps1 -RestoreLocalDrives -RestoreServerManager -DryRun
```

### Monitoring Performance

After optimization:

1. Monitor system performance metrics
2. Test user logon times
3. Verify RDS session stability
4. Check application compatibility

## References

- [Virtual Desktop Optimization Tool](https://github.com/The-Virtual-Desktop-Team/Virtual-Desktop-Optimization-Tool)
- Microsoft Windows Server 2019 optimization guides
- Citrix optimization recommendations
- VMware Horizon optimization guides

## Customization

Both scripts are designed to be easily customizable for specific environments. Review all optimizations before deployment and adjust parameters as needed for your use case.
