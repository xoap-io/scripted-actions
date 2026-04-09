# Google Cloud PowerShell - VM Management Scripts

PowerShell scripts for managing Google Compute Engine VM instances
using the `GoogleCloud` PowerShell module.

## Prerequisites

- GoogleCloud PowerShell module:
  `Install-Module -Name GoogleCloud`
- PowerShell 5.1 or later
- Active Google Cloud project with Compute Engine API enabled
- GCP project configured and authenticated

## Available Scripts

| Script                 | Description                                                                                                   |
| ---------------------- | ------------------------------------------------------------------------------------------------------------- |
| `gce-ps-create-vm.ps1` | Create a new Compute Engine VM instance using `Add-GceInstance`                                               |
| `gce-ps-start-vm.ps1`  | Start a stopped Compute Engine VM instance using `Start-GceInstance`                                          |
| `gce-ps-stop-vm.ps1`   | Stop a running Compute Engine VM instance using `Stop-GceInstance`                                            |
| `gce-ps-list-vms.ps1`  | List Compute Engine VM instances with optional status filter and Table or JSON output using `Get-GceInstance` |
| `gce-ps-delete-vm.ps1` | Delete a Compute Engine VM instance using `Remove-GceInstance`, with typed YES confirmation                   |

## Usage Examples

### Start VM Instance

```powershell
.\gce-ps-start-vm.ps1 `
  -ProjectId "my-project-123" `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01"
```

### Stop VM Instance

```powershell
.\gce-ps-stop-vm.ps1 `
  -ProjectId "my-project-123" `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01" `
  -Force
```

### List VM Instances

```powershell
# List all running instances across all zones
.\gce-ps-list-vms.ps1 `
  -ProjectId "my-project-123" `
  -Status Running `
  -OutputFormat Table

# List all instances in a specific zone as JSON
.\gce-ps-list-vms.ps1 `
  -ProjectId "my-project-123" `
  -Zone "us-central1-a" `
  -OutputFormat JSON
```

### Delete VM Instance

```powershell
.\gce-ps-delete-vm.ps1 `
  -ProjectId "my-project-123" `
  -Zone "us-central1-a" `
  -InstanceName "old-server-01" `
  -Force
```

### Create VM Instance

Basic VM with minimal configuration:

```powershell
.\gce-ps-create-vm.ps1 `
  -Project "my-project-123" `
  -Zone "us-central1-a" `
  -Name "web-server-01" `
  -MachineType "e2-medium"
```

Production VM with image, disk, tags, and labels:

```powershell
.\gce-ps-create-vm.ps1 `
  -Project "my-project-123" `
  -Zone "us-central1-a" `
  -Name "app-server" `
  -MachineType "n1-standard-2" `
  -ImageFamily "debian-11" `
  -ImageProject "debian-cloud" `
  -DiskSizeGb 50 `
  -Tag @("web-server", "https-server") `
  -Label @{ env = "prod"; team = "backend" }
```

Preemptible VM with no external IP and startup script:

```powershell
.\gce-ps-create-vm.ps1 `
  -Project "my-project-123" `
  -Zone "us-west1-b" `
  -Name "dev-instance" `
  -MachineType "e2-micro" `
  -ImageFamily "ubuntu-2004-lts" `
  -ImageProject "ubuntu-os-cloud" `
  -Preemptible `
  -NoExternalIp `
  -Metadata @{ "startup-script" = "#!/bin/bash`napt update" }
```
