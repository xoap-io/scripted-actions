# XenServer CLI - Network Management Scripts

This directory contains PowerShell scripts for managing Citrix XenServer/XCP-ng networking using XenServerPSModule.

## Prerequisites

- XenServerPSModule installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- XenServer/XCP-ng access
- Network administrative credentials

## Available Scripts

Scripts for managing XenServer networking:

### Network Operations

- Create virtual networks
- Configure VLANs
- Network bonding
- VLAN tagging

### Virtual Interfaces

- VIF (Virtual Interface) management
- Network adapter configuration
- QoS settings

### Physical Networking

- PIF (Physical Interface) management
- Network bond creation
- Link aggregation

## Usage Examples

### Connect to XenServer

```powershell
# Import module and connect
Import-Module XenServerPSModule
$session = Connect-XenServer -Server "xenserver.domain.com" -UserName "root" -Password "password"
```

### Create Network

```powershell
# Create internal network
$network = New-XenNetwork -SessionOpaqueRef $session `
    -NameLabel "Internal-Network" `
    -NameDescription "Internal VM network" `
    -Managed $true

# Create VLAN network
$pif = Get-XenPIF -SessionOpaqueRef $session | Where-Object {$_.device -eq "eth0"}
$vlanNetwork = New-XenNetwork -SessionOpaqueRef $session `
    -NameLabel "VLAN-100" `
    -NameDescription "Production VLAN 100"

# Create VLAN on PIF
$vlanPif = New-XenVLAN -SessionOpaqueRef $session `
    -TaggedPIF $pif.opaque_ref `
    -Tag 100 `
    -Network $vlanNetwork.opaque_ref
```

### Network Bonding

```powershell
# Create network bond for redundancy
$pif1 = Get-XenPIF -SessionOpaqueRef $session | Where-Object {$_.device -eq "eth0"}
$pif2 = Get-XenPIF -SessionOpaqueRef $session | Where-Object {$_.device -eq "eth1"}

$network = Get-XenNetwork -SessionOpaqueRef $session | Where-Object {$_.name_label -eq "Pool-wide network"}

# Create bond (LACP mode)
$bond = New-XenBond -SessionOpaqueRef $session `
    -Network $network.opaque_ref `
    -Members @($pif1.opaque_ref, $pif2.opaque_ref) `
    -Mode "lacp"

# Available modes:
# - "balance-slb" - Source Load Balancing
# - "active-backup" - Active/Passive
# - "lacp" - Link Aggregation Control Protocol
```

### Manage Virtual Interfaces (VIFs)

```powershell
# Create VIF (attach network to VM)
$vm = Get-XenVM -SessionOpaqueRef $session | Where-Object {$_.name_label -eq "MyVM"}
$network = Get-XenNetwork -SessionOpaqueRef $session | Where-Object {$_.name_label -eq "VLAN-100"}

$vif = New-XenVIF -SessionOpaqueRef $session `
    -VM $vm.opaque_ref `
    -Network $network.opaque_ref `
    -Device "0" `
    -MAC "auto"

# Attach VIF to running VM
Invoke-XenVIF -SessionOpaqueRef $session `
    -Uuid $vif.uuid `
    -XenAction Plug
```

## XenServer Networking Best Practices

- **Network Redundancy**:

  - Use network bonding for critical networks
  - Implement LACP when switch supports it
  - Separate management network
  - Use active-backup for simple redundancy

- **VLAN Configuration**:

  - Proper VLAN planning
  - Document VLAN assignments
  - Use trunk ports on switches
  - Consistent VLAN IDs across infrastructure

- **Performance**:

  - Enable jumbo frames (MTU 9000) for storage networks
  - Use separate networks for different traffic types
  - Monitor network throughput
  - Balance VM distribution across bonds

- **Security**:
  - Isolate management network
  - Implement proper VLAN segmentation
  - Use private VLANs when appropriate
  - Regular security audits

## Network Types

### Pool-wide Network

- Shared across all hosts in pool
- Automatic on all new hosts
- Used for VM connectivity

### Host-only Network

- Single host network
- Not shared in pool
- Special use cases

### External Network

- Connected to physical network
- VM external connectivity
- VLAN support

### Private Network

- Internal-only communication
- No external access
- VM-to-VM communication

## Bonding Modes

### balance-slb (Source Load Balancing)

- Default XenServer mode
- Active-active
- No switch configuration required
- Load balancing based on MAC addresses

### active-backup

- Active-passive
- Simple failover
- No switch configuration required
- One active member at a time

### lacp (802.3ad)

- Active-active with LACP
- Requires switch support
- Dynamic link aggregation
- Best performance when configured properly

## Error Handling

Scripts include:

- Network connectivity validation
- Interface availability checks
- VLAN validation
- Bond configuration verification
- Comprehensive error messages

## Related Documentation

- [XenServer Networking Guide](https://docs.citrix.com/en-us/citrix-hypervisor/networking.html)
- [Open vSwitch Documentation](https://www.openvswitch.org/support/dist-docs/)
- [XenServer SDK](https://docs.citrix.com/en-us/citrix-hypervisor/sdk/)

## Support

For issues or questions, please refer to the main repository documentation.
