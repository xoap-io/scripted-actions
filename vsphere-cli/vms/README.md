# vSphere CLI - VM Management Scripts

This directory contains PowerShell scripts for managing VMware vSphere virtual machines using PowerCLI.

## Prerequisites

- VMware PowerCLI 12.0 or later installed:
  - `Install-Module -Name VMware.PowerCLI -Scope CurrentUser`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- vCenter Server or ESXi access
- Appropriate VM management permissions

## Available Scripts

Scripts for managing vSphere virtual machines:

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
