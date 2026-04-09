# XenServer CLI - Storage Management Scripts

This directory contains PowerShell scripts for managing Citrix XenServer and
XCP-ng storage repositories using XenServerPSModule.

## Prerequisites

- XenServerPSModule (from Citrix XenServer SDK)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- XenServer or XCP-ng pool coordinator access
- Storage administrative credentials

## Available Scripts

| Script                                  | Description                                                                                                                                  |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `xenserver-cli-sr-operations.ps1`       | Creates, destroys, scans, lists, and probes storage repositories; supports NFS, iSCSI, HBA (Fibre Channel), local VHD, EXT, and ISO SR types |
| `xenserver-cli-snapshot-operations.ps1` | Lists, creates, and deletes VDI (virtual disk image) snapshots within a storage repository                                                   |

## Usage Examples

### VDI Snapshot Operations

```powershell
# List all VDIs and snapshots in an SR
.\xenserver-cli-snapshot-operations.ps1 `
    -XenServer "xenserver.local" `
    -Credential (Get-Credential) `
    -SrName "NFS-Storage" `
    -Action List

# Create a VDI snapshot
.\xenserver-cli-snapshot-operations.ps1 `
    -XenServer "xenserver.local" `
    -Credential (Get-Credential) `
    -SrName "NFS-Storage" `
    -Action Snapshot `
    -VdiName "WebServer-disk" `
    -SnapshotName "pre-upgrade"

# Delete a VDI snapshot
.\xenserver-cli-snapshot-operations.ps1 `
    -XenServer "xenserver.local" `
    -Credential (Get-Credential) `
    -SrName "NFS-Storage" `
    -Action Delete `
    -SnapshotName "pre-upgrade"
```

### Storage Repository Operations

```powershell
# Create an NFS storage repository
.\xenserver-cli-sr-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "Create" `
    -SRName "NFS-Storage" `
    -SRType "nfs" `
    -ServerPath "nfs-server.local:/exports/xen" `
    -Shared

# List all storage repositories
.\xenserver-cli-sr-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "List"

# Scan an SR to detect new VDIs
.\xenserver-cli-sr-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "Scan" `
    -SRUUID "12345678-abcd-1234-abcd-123456789012"

# Create an iSCSI SR
.\xenserver-cli-sr-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "Create" `
    -SRName "iSCSI-Production" `
    -SRType "lvmoiscsi" `
    -TargetIP "192.168.1.100" `
    -TargetIQN "iqn.2024-01.com.example:storage" `
    -SCSIid "scsi-device-id" `
    -Shared

# Destroy an SR by UUID
.\xenserver-cli-sr-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "Destroy" `
    -SRUUID "12345678-abcd-1234-abcd-123456789012"
```
