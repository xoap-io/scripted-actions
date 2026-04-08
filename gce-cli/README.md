# Google Cloud CLI Scripts

PowerShell scripts that automate Google Cloud Platform operations
using the gcloud CLI. Each script is self-contained with parameter
validation and error handling.

## Prerequisites

- Google Cloud SDK (includes gcloud CLI) —
  [installation guide](https://cloud.google.com/sdk/docs/install)
- PowerShell 5.1 or later
- Active Google Cloud project with appropriate permissions
- Authenticated gcloud session (`gcloud auth login`)

## Directory Structure

| Directory | Description |
| --- | --- |
| `vms/` | VM instance management scripts |

## Available Scripts

| Script | Description |
| --- | --- |
| `gce-cli-delete-running-vms.ps1` | Bulk delete running VMs and associated resources in one or more zones |
| `vms/gce-cli-create-vm.ps1` | Create a new Compute Engine VM instance |

## Usage Examples

### Delete Running VMs

```powershell
.\gce-cli-delete-running-vms.ps1 `
  -Project "my-project-123" `
  -Zone "us-central1-a"
```

Delete VMs across multiple zones, skipping confirmation:

```powershell
.\gce-cli-delete-running-vms.ps1 `
  -Project "my-project-123" `
  -Zone "us-central1-a,us-west1-b" `
  -Force
```

Preview what would be deleted without making changes:

```powershell
.\gce-cli-delete-running-vms.ps1 `
  -Project "my-project-123" `
  -Zone "us-central1-a" `
  -Filter "labels.environment=dev" `
  -WhatIf
```

### Create VM Instance

```powershell
.\vms\gce-cli-create-vm.ps1 `
  -Project "my-project-123" `
  -Zone "us-central1-a" `
  -InstanceName "web-server-01" `
  -MachineType "e2-medium" `
  -ImageFamily "debian-11" `
  -ImageProject "debian-cloud" `
  -DiskSize 20
```
