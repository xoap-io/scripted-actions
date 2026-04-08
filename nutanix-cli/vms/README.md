# Nutanix CLI - VM Management Scripts

This directory contains PowerShell scripts for managing Nutanix AHV virtual
machines via the Nutanix PowerShell SDK.

## Prerequisites

- Nutanix PowerShell SDK (`Nutanix.PowerShell.SDK`)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Nutanix Prism Central or Prism Element access
- VM management permissions

## Available Scripts

| Script | Description |
| --- | --- |
| `nutanix-cli-create-vm.ps1` | Creates new AHV VMs from scratch or by cloning from an existing VM or image; supports bulk creation |
| `nutanix-cli-vm-power-operations.ps1` | Performs start, stop, reboot, and suspend operations on single or multiple VMs, with optional snapshot creation |
| `nutanix-cli-windows-updates.ps1` | Scans and installs Windows updates on AHV-hosted Windows VMs via PowerShell remoting, with pre-update snapshot support |

## Usage Examples

### Create VM

```powershell
# Create a single VM from an image
.\nutanix-cli-create-vm.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMName "WebServer01" `
    -ClusterName "Prod-Cluster" `
    -CPUCores 4 `
    -MemoryGB 8 `
    -DiskSizeGB 60 `
    -ImageName "Ubuntu-22.04" `
    -NetworkName "VLAN100" `
    -PowerOnAfterCreation
```

### VM Power Operations

```powershell
# Start a VM
.\nutanix-cli-vm-power-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMName "WebServer01" `
    -Operation "Start"

# Reboot multiple VMs with a pre-reboot snapshot
.\nutanix-cli-vm-power-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMNames @("Web01", "Web02") `
    -Operation "Reboot" `
    -GracefulShutdown `
    -CreateSnapshot `
    -SnapshotName "BeforeReboot"

# Stop all VMs in a cluster gracefully
.\nutanix-cli-vm-power-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -ClusterName "Production" `
    -Operation "Stop" `
    -GracefulShutdown `
    -Force
```

### Windows Updates

```powershell
# Install security and critical updates on specific VMs
.\nutanix-cli-windows-updates.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMNames @("srv01", "srv02") `
    -UpdateCategories @("Security", "Critical") `
    -DomainCredential (Get-Credential) `
    -AutoReboot

# Scan for updates only, export results to CSV
.\nutanix-cli-windows-updates.ps1 `
    -PrismCentral "pc.domain.com" `
    -ClusterName "Production" `
    -ScanOnly `
    -LocalCredential (Get-Credential) `
    -OutputFormat "CSV" `
    -OutputPath "update-scan.csv"
```
