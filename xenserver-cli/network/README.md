# XenServer CLI - Network Management Scripts

This directory contains PowerShell scripts for managing Citrix XenServer and
XCP-ng networking using XenServerPSModule.

## Prerequisites

- XenServerPSModule (from Citrix XenServer SDK)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- XenServer or XCP-ng pool coordinator access
- Network administrative credentials

## Available Scripts

| Script | Description |
| --- | --- |
| `xenserver-cli-network-operations.ps1` | Creates and manages virtual networks, VLANs, and NIC bonds; supports listing and destroying networks |

## Usage Examples

### Network Operations

```powershell
# Create a simple virtual network
.\xenserver-cli-network-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "CreateNetwork" `
    -NetworkName "VM-Network"

# Create a VLAN-tagged network on a physical interface
.\xenserver-cli-network-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "CreateVLAN" `
    -NetworkName "VLAN-100" `
    -VLANTag 100 `
    -PIFUUID "87654321-4321-4321-4321-210987654321"

# Create an active-backup bond
.\xenserver-cli-network-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "CreateBond" `
    -NetworkName "bond0" `
    -PIFUUIDs @("uuid1", "uuid2") `
    -BondMode "active-backup"

# List all networks
.\xenserver-cli-network-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "List"

# Destroy a network by UUID
.\xenserver-cli-network-operations.ps1 `
    -Server "xenserver.local" `
    -Operation "Destroy" `
    -NetworkUUID "12345678-abcd-1234-abcd-123456789012"
```
