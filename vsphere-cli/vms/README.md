# vSphere CLI - VM Management Scripts

This directory contains PowerShell scripts for managing VMware vSphere virtual
machines using PowerCLI.

## Prerequisites

- VMware PowerCLI 12.0 or later installed:
  - `Install-Module -Name VMware.PowerCLI -Scope CurrentUser`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- vCenter Server or ESXi access
- Appropriate VM management permissions

## Available Scripts

| Script                               | Description                                                                                                                   |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `vsphere-cli-clone-vm.ps1`           | Clone VMs or templates with support for full clones, linked clones, and bulk operations                                       |
| `vsphere-cli-manage-vm-tags.ps1`     | Assign, remove, or list vSphere tag assignments on VMs using `New-TagAssignment`, `Remove-TagAssignment`, `Get-TagAssignment` |
| `vsphere-cli-bulk-vm-operations.ps1` | Perform bulk power (Start, Stop, Suspend, Restart) or snapshot operations on VMs matching a name pattern or tag               |

### VM Lifecycle

- Create VMs from templates
- Clone VMs
- Power operations (on/off/restart)
- Delete VMs
- Snapshot management

### VM Configuration

- CPU/memory adjustments
- Virtual disk management
- Network adapter configuration
- CD/DVD operations
- Hardware version upgrades

### Bulk Operations

- Batch VM creation
- Mass power operations
- Bulk configuration changes

## Usage Examples

### Manage VM Tags

```powershell
$cred = Get-Credential

# List all tags on a VM
.\vsphere-cli-manage-vm-tags.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred `
    -VmName "WebServer01" `
    -Action List

# Assign a tag
.\vsphere-cli-manage-vm-tags.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred `
    -VmName "WebServer01" `
    -Action Assign `
    -TagName "Production" `
    -CategoryName "Environment"

# Remove a tag
.\vsphere-cli-manage-vm-tags.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred `
    -VmName "WebServer01" `
    -Action Remove `
    -TagName "Production"
```

### Bulk VM Operations

```powershell
$cred = Get-Credential

# Stop all Dev VMs without confirmation
.\vsphere-cli-bulk-vm-operations.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred `
    -VmNamePattern "Dev-*" `
    -Action Stop `
    -Force

# Snapshot all VMs with a specific tag
.\vsphere-cli-bulk-vm-operations.ps1 `
    -Server "vcenter.domain.com" `
    -Credential $cred `
    -TagName "PrePatch" `
    -Action Snapshot `
    -SnapshotName "PrePatch-20260408"
```

### Connect to vCenter

```powershell
# Connect to vCenter
Connect-VIServer -Server vcenter.domain.com -User administrator@vsphere.local
```

### Create VM from Template

```powershell
# Create VM from template
New-VM -Name "WebServer01" `
    -Template "Windows-Server-2022-Template" `
    -ResourcePool "Production" `
    -Datastore "Production-DS01" `
    -DiskStorageFormat Thin `
    -Location "Production VMs"

# Customize VM specifications
Set-VM -VM "WebServer01" `
    -NumCpu 4 `
    -MemoryGB 8 `
    -Confirm:$false

# Add network adapter
New-NetworkAdapter -VM "WebServer01" `
    -NetworkName "Production-VLAN100" `
    -StartConnected `
    -Type Vmxnet3

# Power on VM
Start-VM -VM "WebServer01"
```

### Clone VM

```powershell
# Clone VM
New-VM -Name "WebServer02" `
    -VM "WebServer01" `
    -ResourcePool "Production" `
    -Datastore "Production-DS02" `
    -DiskStorageFormat Thin

# Linked clone (faster, saves space)
New-VM -Name "TestVM" `
    -VM "WebServer01" `
    -LinkedClone `
    -ResourcePool "Test" `
    -Datastore "Test-DS01" `
    -ReferenceSnapshot (Get-Snapshot -VM "WebServer01" -Name "Base")
```

### Power Operations

```powershell
# Power on VMs
Get-VM -Name "WebServer*" | Start-VM

# Graceful shutdown
Get-VM -Name "WebServer01" | Shutdown-VMGuest -Confirm:$false

# Force power off
Get-VM -Name "WebServer01" | Stop-VM -Confirm:$false

# Restart VM
Restart-VMGuest -VM "WebServer01" -Confirm:$false
```

### Snapshot Management

```powershell
# Create snapshot
New-Snapshot -VM "WebServer01" `
    -Name "Before Windows Update" `
    -Description "Pre-update backup" `
    -Memory -Quiesce

# List snapshots
Get-Snapshot -VM "WebServer01"

# Revert to snapshot
Set-VM -VM "WebServer01" `
    -Snapshot (Get-Snapshot -VM "WebServer01" -Name "Before Windows Update") `
    -Confirm:$false

# Remove snapshot
Get-Snapshot -VM "WebServer01" -Name "Before Windows Update" | Remove-Snapshot -Confirm:$false

# Remove all snapshots
Get-VM "WebServer01" | Get-Snapshot | Remove-Snapshot -Confirm:$false
```

### VM Configuration Changes

```powershell
# Change CPU and Memory
Set-VM -VM "WebServer01" -NumCpu 8 -MemoryGB 16 -Confirm:$false

# Add hard disk
New-HardDisk -VM "WebServer01" -CapacityGB 100 -StorageFormat Thin

# Extend hard disk
Get-HardDisk -VM "WebServer01" | Where-Object {$_.Name -eq "Hard disk 1"} |
    Set-HardDisk -CapacityGB 200 -Confirm:$false

# Change network
Get-NetworkAdapter -VM "WebServer01" |
    Set-NetworkAdapter -NetworkName "Production-VLAN200" -Confirm:$false

# Enable CPU hot-add
$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
$spec.CpuHotAddEnabled = $true
$vm = Get-VM "WebServer01"
$vm.ExtensionData.ReconfigVM($spec)
```

### Bulk Operations

```powershell
# Create multiple VMs from template
1..10 | ForEach-Object {
    New-VM -Name "WebServer$_" `
        -Template "Windows-Server-2022-Template" `
        -ResourcePool "Production" `
        -Datastore "Production-DS01"
}

# Power off all VMs in a folder
Get-Folder "Test VMs" | Get-VM | Stop-VM -Confirm:$false

# Tag VMs
New-Tag -Name "Production" -Category "Environment"
Get-VM "WebServer*" | New-TagAssignment -Tag "Production"
```

## vSphere VM Best Practices

- **VM Configuration**:

  - Use appropriate hardware versions
  - Install VMware Tools
  - Use VMXNET3 network adapters
  - Thin provision disks when appropriate
  - Separate OS and data disks

- **Resource Management**:

  - Right-size CPU and memory
  - Use reservations sparingly
  - Set appropriate shares
  - Avoid over-commitment

- **Storage**:

  - Use VMware paravirtual SCSI adapters
  - Spread VMs across datastores
  - Monitor datastore space
  - Use storage DRS

- **Snapshots**:

  - Use for short-term protection only
  - Don't keep snapshots indefinitely
  - Consolidate when no longer needed
  - Avoid snapshots on production databases

- **Security**:
  - Minimize virtual hardware
  - Disable unnecessary features
  - Use secure boot when possible
  - Regular patching
  - Implement role-based access

## VMware Tools

### Benefits

- Enhanced performance
- Better time synchronization
- Guest OS operations
- Improved graphics
- Heartbeat monitoring

### Installation

```powershell
# Mount VMware Tools installer
Mount-Tools -VM "WebServer01"

# Update VMware Tools
Update-Tools -VM "WebServer01" -NoReboot
```

## Error Handling

Scripts include:

- vCenter connectivity validation
- VM existence checks
- Resource availability verification
- State validation
- Comprehensive error messages

## Related Documentation

- [vSphere VM Administration](https://docs.vmware.com/en/VMware-vSphere/8.0/vsphere-vm-administration/GUID-55238059-912E-411F-A0E9-A7A536972A91.html)
- [PowerCLI VM Commands](https://developer.vmware.com/docs/powercli/latest/vmware.vimautomation.core/commands/new-vm/)
- [vSphere Best Practices](https://core.vmware.com/resource/vmware-vsphere-best-practices)

## Support

For issues or questions, please refer to the main repository documentation.
