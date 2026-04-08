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

| Script | Description |
| --- | --- |
| `gce-cli-create-vm.ps1` | Create a new Compute Engine VM instance |

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
