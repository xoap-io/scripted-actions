# XenServer CLI - Infrastructure Management Scripts

This directory contains PowerShell scripts for managing Citrix XenServer and
XCP-ng host infrastructure using XenServerPSModule.

## Prerequisites

- XenServerPSModule (from Citrix XenServer SDK)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- XenServer or XCP-ng pool coordinator access
- Administrative credentials

## Available Scripts

| Script | Description |
| --- | --- |
| `xenserver-cli-host-operations.ps1` | Manages XenServer host operations: enable/disable maintenance mode, evacuate VMs, reboot, shutdown, and health check |

## Usage Examples

### Host Operations

```powershell
# Disable a host and evacuate its VMs
.\xenserver-cli-host-operations.ps1 `
    -Server "xenserver.local" `
    -HostName "xenhost01.local" `
    -Operation "Disable" `
    -EvacuateVMs

# Reboot a host by UUID without confirmation
.\xenserver-cli-host-operations.ps1 `
    -Server "xenserver.local" `
    -HostUUID "12345678-abcd-1234-abcd-123456789012" `
    -Operation "Reboot" `
    -Force

# Run a health check on a host
.\xenserver-cli-host-operations.ps1 `
    -Server "xenserver.local" `
    -HostName "xenhost01.local" `
    -Operation "HealthCheck"

# Re-enable a host after maintenance
.\xenserver-cli-host-operations.ps1 `
    -Server "xenserver.local" `
    -HostName "xenhost01.local" `
    -Operation "Enable"
```
