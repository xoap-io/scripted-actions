# Google Cloud CLI - VM Management Scripts

PowerShell scripts for managing Google Compute Engine VM instances
using the gcloud CLI.

## Prerequisites

- Google Cloud SDK installed (includes gcloud CLI)
- PowerShell 5.1 or later
- Active Google Cloud project with Compute Engine API enabled
- Authenticated gcloud session (`gcloud auth login`)
- Default project set (`gcloud config set project PROJECT_ID`)

## Available Scripts

| Script                           | Description                                                      |
| -------------------------------- | ---------------------------------------------------------------- |
| `gce-cli-create-vm.ps1`          | Create a new Compute Engine VM instance                          |
| `gce-cli-start-vm.ps1`           | Start a stopped VM instance                                      |
| `gce-cli-stop-vm.ps1`            | Stop a running VM instance                                       |
| `gce-cli-list-vms.ps1`           | List VM instances with optional status and format filters        |
| `gce-cli-delete-vm.ps1`          | Delete a VM instance with optional confirmation and disk cleanup |
| `gce-cli-create-vm-snapshot.ps1` | Snapshot a VM persistent disk (boot or attached)                 |

## Usage Examples

### Create VM Instance

```powershell
.\gce-cli-create-vm.ps1 `
  -Project "my-project-123" `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01" `
  -MachineType "e2-medium" `
  -ImageFamily "debian-11" `
  -ImageProject "debian-cloud" `
  -DiskSize 20
```

Create a preemptible VM with tags and labels:

```powershell
.\gce-cli-create-vm.ps1 `
  -Project "my-project-123" `
  -Zone "us-west1-b" `
  -InstanceName "app-server" `
  -MachineType "n1-standard-2" `
  -ImageFamily "ubuntu-2004-lts" `
  -ImageProject "ubuntu-os-cloud" `
  -DiskSize 50 `
  -Preemptible `
  -Tags "web-server,https-server" `
  -Labels "env=prod,team=backend"
```

### Start and Stop VM Instances

```powershell
.\gce-cli-stop-vm.ps1 -InstanceName "web-server-01"
```

```powershell
.\gce-cli-start-vm.ps1 `
  -ProjectId "my-project-123" `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01"
```

### List VM Instances

```powershell
.\gce-cli-list-vms.ps1 -Status Running -OutputFormat Table
```

List all instances in a specific zone as JSON:

```powershell
.\gce-cli-list-vms.ps1 `
  -ProjectId "my-project-123" `
  -Zone "us-central1-a" `
  -Status Running `
  -OutputFormat JSON
```

### Delete a VM Instance

```powershell
.\gce-cli-delete-vm.ps1 `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01"
```

Delete with attached disks and skip confirmation:

```powershell
.\gce-cli-delete-vm.ps1 `
  -ProjectId "my-project-123" `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01" `
  -Force `
  -DeleteDisks
```

Preview what would be deleted:

```powershell
.\gce-cli-delete-vm.ps1 `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01" `
  -WhatIf
```

### Create a VM Disk Snapshot

```powershell
.\gce-cli-create-vm-snapshot.ps1 `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01"
```

Snapshot a named data disk with custom name and storage location:

```powershell
.\gce-cli-create-vm-snapshot.ps1 `
  -ProjectId "my-project-123" `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01" `
  -DiskName "data-disk-01" `
  -SnapshotName "data-backup-20260408" `
  -StorageLocation "eu"
```
