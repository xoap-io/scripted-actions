# XenServer CLI - VM Management Scripts

This directory contains PowerShell scripts for managing Citrix XenServer/XCP-ng virtual machines using XenServerPSModule.

## Prerequisites

- XenServerPSModule installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- XenServer/XCP-ng access
- VM management permissions

## Available Scripts

Scripts for managing XenServer virtual machines:

### VM Lifecycle

- **xenserver-cli-create-vm-from-template.ps1** - Create VMs from templates
- **power-vm-operations.ps1** - Power on/off/restart VMs
- **vm-clone.ps1** - Clone existing VMs
- Delete VMs
- Export/import VMs

### VM Configuration

- CPU/memory adjustments
- Virtual disk management
- Network configuration
- CD/DVD operations
- Snapshot management

## Usage Examples

### Connect to XenServer

```powershell
# Import module and connect
Import-Module XenServerPSModule
$session = Connect-XenServer -Server "xenserver.domain.com" -UserName "root" -Password "password"
```

### Create VM from Template

```powershell
# Get template
$template = Get-XenVM -SessionOpaqueRef $session |
    Where-Object {$_.name_label -eq "Windows Server 2022" -and $_.is_a_template}

# Clone template to create VM
$vm = Copy-XenVM -SessionOpaqueRef $session `
    -Uuid $template.uuid `
    -NewName "WebServer01"

# Configure VM
Set-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -NameDescription "Production Web Server" `
    -VCPUsMax 4 `
    -MemoryStaticMax 8589934592  # 8GB in bytes

# Get storage repository
$sr = Get-XenSR -SessionOpaqueRef $session |
    Where-Object {$_.name_label -eq "NFS-Production"}

# Provision (copy disk from template)
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction Provision

# Start VM
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction Start
```

### Power Operations

```powershell
# Get VM
$vm = Get-XenVM -SessionOpaqueRef $session |
    Where-Object {$_.name_label -eq "WebServer01" -and -not $_.is_a_template}

# Start VM
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction Start

# Clean shutdown
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction CleanShutdown

# Force shutdown
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction HardShutdown

# Reboot (clean)
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction CleanReboot

# Suspend VM
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction Suspend

# Resume VM
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction Resume
```

### Clone VM

```powershell
# Full clone
$sourceVm = Get-XenVM -SessionOpaqueRef $session |
    Where-Object {$_.name_label -eq "WebServer01"}

$clonedVm = Copy-XenVM -SessionOpaqueRef $session `
    -Uuid $sourceVm.uuid `
    -NewName "WebServer02"

# Fast clone (shared disk) - for test environments
# Note: Requires template or snapshot
$snapshot = Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $sourceVm.uuid `
    -XenAction Snapshot `
    -NewName "Base-Snapshot"

$fastClone = Copy-XenVM -SessionOpaqueRef $session `
    -Uuid $snapshot.uuid `
    -NewName "TestServer01"
```

### VM Configuration Changes

```powershell
# Change CPU count
Set-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -VCPUsMax 8 `
    -VCPUsAtStartup 8

# Change memory (VM must be shutdown)
Set-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -MemoryStaticMax 17179869184 `  # 16GB
    -MemoryStaticMin 17179869184 `
    -MemoryDynamicMax 17179869184 `
    -MemoryDynamicMin 17179869184

# Add virtual disk
$sr = Get-XenSR -SessionOpaqueRef $session |
    Where-Object {$_.name_label -eq "NFS-Production"}

$vdi = New-XenVDI -SessionOpaqueRef $session `
    -NameLabel "$($vm.name_label)-Data" `
    -SR $sr.opaque_ref `
    -VirtualSize 107374182400  # 100GB

# Attach disk to VM
$vbd = New-XenVBD -SessionOpaqueRef $session `
    -VM $vm.opaque_ref `
    -VDI $vdi.opaque_ref `
    -Userdevice "1" `
    -Mode "RW" `
    -Type "Disk" `
    -Bootable $false

# Plug VBD if VM is running
Invoke-XenVBD -SessionOpaqueRef $session `
    -Uuid $vbd.uuid `
    -XenAction Plug
```

### Snapshot Management

```powershell
# Create snapshot
$snapshot = Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $vm.uuid `
    -XenAction Snapshot `
    -NewName "Before-Update-$(Get-Date -Format 'yyyy-MM-dd')"

# List snapshots
Get-XenVM -SessionOpaqueRef $session |
    Where-Object {$_.is_a_snapshot -and $_.snapshot_of -eq $vm.opaque_ref} |
    Select-Object name_label, snapshot_time

# Revert to snapshot
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $snapshot.uuid `
    -XenAction Revert

# Delete snapshot
Invoke-XenVM -SessionOpaqueRef $session `
    -Uuid $snapshot.uuid `
    -XenAction Destroy
```

### Bulk Operations

```powershell
# Get all VMs (not templates)
$vms = Get-XenVM -SessionOpaqueRef $session |
    Where-Object {-not $_.is_a_template -and -not $_.is_control_domain}

# Start all VMs with specific tag
$vms | Where-Object {$_.tags -contains "Production"} | ForEach-Object {
    Invoke-XenVM -SessionOpaqueRef $session -Uuid $_.uuid -XenAction Start
}

# Shutdown all VMs in specific folder/tag
$vms | Where-Object {$_.tags -contains "Test"} | ForEach-Object {
    Invoke-XenVM -SessionOpaqueRef $session -Uuid $_.uuid -XenAction CleanShutdown
}
```

## XenServer VM Best Practices

- **VM Creation**:

  - Use templates for consistency
  - Install XenServer Tools (Citrix VM Tools)
  - Use appropriate virtual hardware
  - Configure proper network settings

- **Resource Allocation**:

  - Right-size CPU and memory
  - Don't over-commit resources
  - Use dynamic memory when appropriate
  - Monitor resource usage

- **Storage**:

  - Use shared storage for HA
  - Separate OS and data disks
  - Regular snapshot management
  - Don't keep snapshots long-term

- **Performance**:

  - Install XenServer Tools
  - Use paravirtualized drivers
  - Proper virtual hardware configuration
  - Monitor performance metrics

- **High Availability**:
  - Use shared storage
  - Configure HA priorities
  - Regular failover testing
  - Redundant network paths

## XenServer Tools

### Benefits

- Enhanced performance
- Better time synchronization
- Graceful shutdown/reboot
- Clipboard integration (Windows)
- Agent-based operations

### Installation

- Windows: Install from XenServer ISO
- Linux: Install xe-guest-utilities package

## VM Power States

- **Running**: VM is running
- **Halted**: VM is stopped
- **Suspended**: VM is paused, memory saved
- **Paused**: VM execution paused

## Error Handling

Scripts include:

- Session validation
- VM existence checks
- Power state validation
- Resource availability verification
- Comprehensive error messages

## Related Documentation

- [XenServer VM Guide](https://docs.citrix.com/en-us/citrix-hypervisor/vms.html)
- [XenServer SDK](https://docs.citrix.com/en-us/citrix-hypervisor/sdk/)
- [XCP-ng Documentation](https://docs.xcp-ng.org/)

## Support

For issues or questions, please refer to the main repository documentation.
