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

| Directory  | Description                                      |
| ---------- | ------------------------------------------------ |
| `vms/`     | VM instance management scripts                   |
| `network/` | VPC network, subnet, and firewall rule scripts   |
| `storage/` | Cloud Storage bucket and persistent disk scripts |

## Available Scripts

| Script                                     | Description                                                           |
| ------------------------------------------ | --------------------------------------------------------------------- |
| `gce-cli-delete-running-vms.ps1`           | Bulk delete running VMs and associated resources in one or more zones |
| `vms/gce-cli-create-vm.ps1`                | Create a new Compute Engine VM instance                               |
| `vms/gce-cli-start-vm.ps1`                 | Start a stopped VM instance                                           |
| `vms/gce-cli-stop-vm.ps1`                  | Stop a running VM instance                                            |
| `vms/gce-cli-list-vms.ps1`                 | List VM instances with optional status and format filters             |
| `vms/gce-cli-delete-vm.ps1`                | Delete a VM instance with optional confirmation and disk cleanup      |
| `vms/gce-cli-create-vm-snapshot.ps1`       | Snapshot a VM persistent disk (boot or attached)                      |
| `network/gce-cli-create-vpc.ps1`           | Create a VPC network with auto or custom subnet mode                  |
| `network/gce-cli-create-firewall-rule.ps1` | Create a VPC firewall rule (ingress/egress, allow/deny)               |
| `network/gce-cli-create-subnet.ps1`        | Create a subnetwork in an existing custom-mode VPC                    |
| `storage/gce-cli-create-bucket.ps1`        | Create a Cloud Storage bucket with configurable location and class    |
| `storage/gce-cli-upload-object.ps1`        | Upload a local file or folder to a Cloud Storage bucket               |
| `storage/gce-cli-create-disk.ps1`          | Create a persistent disk (blank, from image, or from snapshot)        |

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

### Create a VPC Network

```powershell
.\network\gce-cli-create-vpc.ps1 `
  -ProjectId "my-project-123" `
  -NetworkName "prod-network" `
  -SubnetMode custom
```

### Create a Cloud Storage Bucket

```powershell
.\storage\gce-cli-create-bucket.ps1 `
  -ProjectId "my-project-123" `
  -BucketName "my-app-assets-20260408" `
  -Location "EU" `
  -EnableUniformAccess
```
