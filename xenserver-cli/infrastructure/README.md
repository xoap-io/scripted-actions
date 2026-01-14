# XenServer CLI - Infrastructure Management Scripts

This directory contains PowerShell scripts for managing Citrix XenServer/XCP-ng infrastructure using XenServerPSModule.

## Prerequisites

- XenServerPSModule installed:
  - Download from Citrix XenServer SDK
  - `Import-Module XenServerPSModule`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- XenServer/XCP-ng pool or standalone host
- Network access to XenServer
- Administrative credentials

## Available Scripts

Scripts for managing XenServer infrastructure:

### Pool Management

- Create resource pools
- Add/remove servers to pool
- Pool master operations
- HA configuration

### Host Management

- Host configuration
- Maintenance mode
- Patch management
- License management

### Storage Management

- Storage repository (SR) creation
- Shared storage configuration
- Local storage management
- iSCSI/NFS setup

### Network Management

- Network creation
- VLAN configuration
- Bonding setup
- Virtual switch management

## Usage Examples

### Connect to XenServer

```powershell
# Import module
Import-Module XenServerPSModule

# Connect to XenServer
$session = Connect-XenServer -Server "xenserver.domain.com" `
    -UserName "root" `
    -Password "password"
```

### Pool Operations

```powershell
# Get pool information
$pool = Get-XenPool -SessionOpaqueRef $session

# Join host to pool
# On the joining host:
Join-XenPool -SessionOpaqueRef $session `
    -MasterAddress "pool-master.domain.com" `
    -MasterUsername "root" `
    -MasterPassword "password"

# Configure HA
Set-XenPool -SessionOpaqueRef $session `
    -Uuid $pool.uuid `
    -HaEnabled $true
```

### Host Management

```powershell
# Get hosts
$hosts = Get-XenHost -SessionOpaqueRef $session

# Enable maintenance mode
Invoke-XenHost -SessionOpaqueRef $session `
    -Uuid $host.uuid `
    -XenAction Disable

# Disable maintenance mode (enable host)
Invoke-XenHost -SessionOpaqueRef $session `
    -Uuid $host.uuid `
    -XenAction Enable

# Reboot host
Invoke-XenHost -SessionOpaqueRef $session `
    -Uuid $host.uuid `
    -XenAction Reboot
```

### Storage Repository Management

```powershell
# Create NFS SR
$sr = New-XenSR -SessionOpaqueRef $session `
    -NameLabel "NFS-Storage" `
    -NameDescription "Production NFS Storage" `
    -Type "nfs" `
    -DeviceConfig @{
        "server" = "nfs-server.domain.com"
        "serverpath" = "/export/xenserver"
    } `
    -PhysicalSize 1099511627776

# Create iSCSI SR
$sr = New-XenSR -SessionOpaqueRef $session `
    -NameLabel "iSCSI-Storage" `
    -Type "lvmoiscsi" `
    -DeviceConfig @{
        "target" = "192.168.1.100"
        "targetIQN" = "iqn.2024-01.com.example:storage"
    }

# List storage repositories
Get-XenSR -SessionOpaqueRef $session | Select-Object name_label, type, physical_size
```

## XenServer Best Practices

- **Pool Configuration**:

  - Use resource pools for HA and load balancing
  - Configure shared storage for live migration
  - Implement proper network segregation
  - Regular pool database backups

- **High Availability**:

  - Enable HA on pools (minimum 3 hosts)
  - Configure fencing/STONITH
  - Use shared storage
  - Regular failover testing

- **Storage**:

  - Use shared storage for production VMs
  - Separate boot and data storage
  - Monitor SR capacity
  - Regular SR health checks

- **Networking**:

  - Use network bonding for redundancy
  - Separate management, storage, and VM networks
  - Implement VLANs appropriately
  - Configure MTU correctly

- **Performance**:
  - Balance VM distribution
  - Monitor resource usage
  - Use appropriate storage types
  - Enable thin provisioning when appropriate

## XenServer Architecture

### Resource Pools

- Shared resource management
- Centralized management
- High availability
- Live migration support
- Up to 64 hosts per pool

### Storage Types

- **Local Storage**: Direct-attached storage
- **NFS**: Network File System
- **iSCSI**: Block-level storage
- **FC/FCoE**: Fibre Channel
- **GFS2**: Clustered file system

### Networking

- Open vSwitch
- Network bonding (LACP, active-backup)
- VLANs
- SDN integration

## Error Handling

Scripts include:

- Session validation
- Connection checks
- Resource availability verification
- Pool state validation
- Comprehensive error messages

## Related Documentation

- [XenServer Documentation](https://docs.citrix.com/en-us/citrix-hypervisor/)
- [XenServer SDK Guide](https://docs.citrix.com/en-us/citrix-hypervisor/sdk/)
- [XCP-ng Documentation](https://docs.xcp-ng.org/)

## Support

For issues or questions, please refer to the main repository documentation.
