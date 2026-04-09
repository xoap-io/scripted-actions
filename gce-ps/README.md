# Google Cloud PowerShell Scripts

PowerShell scripts that automate Google Cloud Platform operations
using the `GoogleCloud` PowerShell module (`Add-GceInstance`,
`Get-GceInstance`, etc.). Each script is self-contained with
parameter validation and error handling.

## Prerequisites

- GoogleCloud PowerShell module:
  `Install-Module -Name GoogleCloud`
- PowerShell 5.1 or later
- Active Google Cloud project with appropriate permissions
- GCP project configured and authenticated

## Directory Structure

| Directory | Description                    |
| --------- | ------------------------------ |
| `vms/`    | VM instance management scripts |

## Available Scripts

| Script                     | Description                                                                           |
| -------------------------- | ------------------------------------------------------------------------------------- |
| `vms/gce-ps-create-vm.ps1` | Create a new Compute Engine VM instance using `Add-GceInstance`                       |
| `vms/gce-ps-start-vm.ps1`  | Start a stopped Compute Engine VM instance using `Start-GceInstance`                  |
| `vms/gce-ps-stop-vm.ps1`   | Stop a running Compute Engine VM instance using `Stop-GceInstance`                    |
| `vms/gce-ps-list-vms.ps1`  | List Compute Engine VM instances with optional status filter and Table or JSON output |
| `vms/gce-ps-delete-vm.ps1` | Delete a Compute Engine VM instance using `Remove-GceInstance`                        |

## Usage Examples

### Create VM Instance

```powershell
.\vms\gce-ps-create-vm.ps1 `
  -Project "my-project-123" `
  -Zone "us-central1-a" `
  -Name "web-server-01" `
  -MachineType "e2-medium"
```

Create a production VM with specific image and labels:

```powershell
.\vms\gce-ps-create-vm.ps1 `
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
