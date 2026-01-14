# XenServer CLI - Storage Management Scripts

This directory contains PowerShell scripts for managing Citrix XenServer/XCP-ng storage using XenServerPSModule.

## Prerequisites

- XenServerPSModule installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- XenServer/XCP-ng access
- Storage administrative credentials

## Available Scripts

Scripts for managing XenServer storage:

### Storage Repository (SR) Management

- Create storage repositories
- Manage SR types (Local, NFS, iSCSI, FC)
- SR health checks
- Capacity management

### Virtual Disk Operations

- VDI (Virtual Disk Image) creation
- Disk resizing
- Snapshot management
- Disk cloning

### Storage Configuration

- Thin provisioning
- Storage multipathing
- SR migration
- Storage performance tuning

## Usage Examples

### Connect to XenServer

```powershell
# Import module and connect
Import-Module XenServerPSModule
$session = Connect-XenServer -Server "xenserver.domain.com" -UserName "root" -Password "password"
```

### Create Storage Repositories

```powershell
# Create Local SR (EXT filesystem)
$localSR = New-XenSR -SessionOpaqueRef $session `
    -NameLabel "Local-Storage" `
    -NameDescription "Local disk storage" `
    -Type "ext" `
    -DeviceConfig @{
        "device" = "/dev/sdb"
    } `
    -ContentType "user" `
    -Shared $false

# Create NFS SR
$nfsSR = New-XenSR -SessionOpaqueRef $session `
    -NameLabel "NFS-Production" `
    -NameDescription "Production NFS Storage" `
    -Type "nfs" `
    -DeviceConfig @{
        "server" = "nfs-server.domain.com"
        "serverpath" = "/export/xenserver"
    } `
    -ContentType "user" `
    -Shared $true

# Create iSCSI SR
$iscsiSR = New-XenSR -SessionOpaqueRef $session `
    -NameLabel "iSCSI-Storage" `
    -NameDescription "Production iSCSI Storage" `
    -Type "lvmoiscsi" `
    -DeviceConfig @{
        "target" = "192.168.1.100"
        "targetIQN" = "iqn.2024-01.com.example:storage"
        "chapuser" = "username"
        "chappassword" = "password"
    } `
    -ContentType "user" `
    -Shared $true

# Create HBA/FC SR (Fibre Channel)
$fcSR = New-XenSR -SessionOpaqueRef $session `
    -NameLabel "FC-Storage" `
    -NameDescription "Fibre Channel Storage" `
    -Type "lvmohba" `
    -DeviceConfig @{
        "SCSIid" = "scsi-id-of-lun"
    } `
    -ContentType "user" `
    -Shared $true
```

### Manage Virtual Disk Images (VDIs)

```powershell
# Create VDI
$sr = Get-XenSR -SessionOpaqueRef $session | Where-Object {$_.name_label -eq "NFS-Production"}

$vdi = New-XenVDI -SessionOpaqueRef $session `
    -NameLabel "DataDisk01" `
    -NameDescription "Additional data disk" `
    -SR $sr.opaque_ref `
    -VirtualSize 107374182400 `
    -Type "user" `
    -Sharable $false `
    -ReadOnly $false

# List VDIs
Get-XenVDI -SessionOpaqueRef $session |
    Select-Object name_label, virtual_size, physical_utilisation |
    Format-Table

# Resize VDI (only increase size)
Set-XenVDI -SessionOpaqueRef $session `
    -Uuid $vdi.uuid `
    -VirtualSize 214748364800

# Clone VDI
$clonedVdi = Copy-XenVDI -SessionOpaqueRef $session `
    -Uuid $vdi.uuid

# Snapshot VDI
$snapshotVdi = Invoke-XenVDI -SessionOpaqueRef $session `
    -Uuid $vdi.uuid `
    -XenAction Snapshot
```

### Storage Health and Monitoring

```powershell
# Get SR information
Get-XenSR -SessionOpaqueRef $session |
    Select-Object name_label,
        @{N="Type"; E={$_.type}},
        @{N="Physical Size GB"; E={[math]::Round($_.physical_size / 1GB, 2)}},
        @{N="Physical Used GB"; E={[math]::Round($_.physical_utilisation / 1GB, 2)}},
        @{N="Free %"; E={[math]::Round((1 - ($_.physical_utilisation / $_.physical_size)) * 100, 2)}} |
    Format-Table

# Scan SR for new VDIs
Invoke-XenSR -SessionOpaqueRef $session `
    -Uuid $sr.uuid `
    -XenAction Scan
```

## XenServer Storage Best Practices

- **SR Planning**:

  - Use shared storage for HA and live migration
  - Separate boot and data storage
  - Plan capacity with growth in mind
  - Monitor storage utilization

- **Performance**:

  - Use local storage for best performance
  - NFS for flexibility and ease of management
  - iSCSI for balance of performance and features
  - FC for enterprise performance
  - Enable multipathing for redundancy

- **Capacity Management**:

  - Monitor SR capacity regularly
  - Use thin provisioning when appropriate
  - Clean up old snapshots
  - Archive unused VDIs

- **Data Protection**:

  - Regular SR backups
  - Use snapshots for short-term protection
  - Implement proper backup solution
  - Test restore procedures

- **High Availability**:
  - Use shared storage for HA pools
  - Implement multipathing
  - Monitor storage connectivity
  - Regular failover testing

## Storage Repository Types

### Local Storage (EXT/LVM)

- **Type**: ext, lvm
- **Use Case**: Non-HA, local VMs
- **Pros**: High performance, simple
- **Cons**: No live migration, single point of failure

### NFS

- **Type**: nfs
- **Use Case**: Shared storage, HA pools
- **Pros**: Easy management, thin provisioning
- **Cons**: Network dependency, potential latency

### iSCSI

- **Type**: lvmoiscsi
- **Use Case**: Block storage, enterprise
- **Pros**: Good performance, HA support
- **Cons**: More complex setup

### Fibre Channel

- **Type**: lvmohba
- **Use Case**: Enterprise SAN
- **Pros**: Best performance, high availability
- **Cons**: Expensive, complex infrastructure

### CIFS/SMB

- **Type**: cifs
- **Use Case**: Windows file shares
- **Pros**: Integration with Windows
- **Cons**: Performance limitations

## Thin Provisioning

### Benefits

- Space efficiency
- Over-provisioning capability
- Reduced initial capacity
- Cost savings

### Considerations

- Monitor actual usage
- Plan for growth
- Regular capacity checks
- Avoid over-commitment

## Multipathing

```powershell
# Enable multipathing for iSCSI
# Configure on storage side first, then:

# Scan for new paths
Invoke-XenSR -SessionOpaqueRef $session `
    -Uuid $sr.uuid `
    -XenAction Scan

# Multipathing is automatic when multiple paths detected
```

## Error Handling

Scripts include:

- Storage connectivity validation
- Capacity checks
- SR availability verification
- Path redundancy checks
- Comprehensive error messages

## Related Documentation

- [XenServer Storage Guide](https://docs.citrix.com/en-us/citrix-hypervisor/storage.html)
- [Storage Types Reference](https://docs.citrix.com/en-us/citrix-hypervisor/storage/types.html)
- [XenServer Best Practices](https://docs.citrix.com/en-us/citrix-hypervisor/system-requirements.html)

## Support

For issues or questions, please refer to the main repository documentation.
