# XenServer CLI - VM Management Scripts

This directory contains PowerShell scripts for managing Citrix XenServer and
XCP-ng virtual machines using XenServerPSModule.

## Prerequisites

- XenServerPSModule (from Citrix XenServer SDK)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- XenServer or XCP-ng pool coordinator access
- VM management permissions

## Available Scripts

| Script | Description |
| --- | --- |
| `xenserver-cli-create-vm-from-template.ps1` | Provisions new VMs from an existing template with configurable CPU, memory, storage, and network; supports bulk creation |
| `xenserver-cli-power-vm-operations.ps1` | Performs start, stop, shutdown, reboot, suspend, resume, pause, and unpause operations on single or multiple VMs |
| `xenserver-cli-vm-clone.ps1` | Clones a VM using fast storage-level disk clone; supports single and batch cloning with automatic naming |

## Usage Examples

### Create VM from Template

```powershell
# Create a single VM from a named template
.\xenserver-cli-create-vm-from-template.ps1 `
    -Server "xenserver.local" `
    -TemplateName "Ubuntu-22.04-Template" `
    -VMName "WebServer01"

# Bulk-create VMs with custom resources
.\xenserver-cli-create-vm-from-template.ps1 `
    -Server "xenserver.local" `
    -TemplateName "Windows-Server-2022" `
    -VMNamePrefix "AppServer" `
    -VMCount 3 `
    -CPUCount 4 `
    -MemoryGB 8 `
    -StartVM

# Create a VM from a template UUID with custom storage
.\xenserver-cli-create-vm-from-template.ps1 `
    -Server "xenserver.local" `
    -TemplateUUID "12345678-1234-1234-1234-123456789012" `
    -VMName "DBServer" `
    -CPUCount 8 `
    -MemoryGB 16 `
    -StorageRepository "SSD-Storage"
```

### Power Operations

```powershell
# Start a VM
.\xenserver-cli-power-vm-operations.ps1 `
    -Server "xenserver.domain.com" `
    -VMName "WebServer01" `
    -Operation "Start"

# Graceful shutdown by UUID
.\xenserver-cli-power-vm-operations.ps1 `
    -Server "xenserver.domain.com" `
    -VMUUID "12345678-abcd-1234-abcd-123456789012" `
    -Operation "Shutdown"

# Start multiple VMs asynchronously
.\xenserver-cli-power-vm-operations.ps1 `
    -Server "xenserver.domain.com" `
    -VMNames @("VM01", "VM02", "VM03") `
    -Operation "Start" `
    -Async
```

### Clone VM

```powershell
# Clone a single VM
.\xenserver-cli-vm-clone.ps1 `
    -Server "xenserver.local" `
    -VMName "Template-Ubuntu" `
    -NewVMName "WebServer01"

# Batch clone with auto-naming
.\xenserver-cli-vm-clone.ps1 `
    -Server "xenserver.local" `
    -VMName "Template-Win" `
    -NamePrefix "TestVM" `
    -Count 5
```
