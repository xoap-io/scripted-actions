# Google Cloud PowerShell - VM Management Scripts

This directory contains PowerShell scripts for managing Google Compute Engine (GCE) virtual machines using Google Cloud PowerShell cmdlets.

## Prerequisites

- Google Cloud PowerShell module installed:
  - `Install-Module -Name GoogleCloud`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- GCP project with Compute Engine API enabled
- Authenticated to GCP
- Project configured
- Compute Engine permissions

## Available Scripts

### VM Lifecycle Management

Scripts for creating, managing, and terminating GCE instances using PowerShell cmdlets:

- **gce-ps-create-vm.ps1** - Create new VM instances
- **gce-ps-start-vm.ps1** - Start stopped instances
- **gce-ps-stop-vm.ps1** - Stop running instances
- **gce-ps-stop-vms.ps1** - Bulk stop VMs
- **gce-ps-restart-vm.ps1** - Restart instances
- **gce-ps-remove-vm.ps1** - Delete instances

## Usage Examples

### Authentication

```powershell
# Authenticate to GCP
Add-GcpConfig -Project "my-project-id" -ServiceAccountKey "path\to\key.json"

# Or use user authentication
Add-GcpConfig -Project "my-project-id"
```

### Create VM Instance

```powershell
# Create basic VM
New-GceInstance `
    -Project "my-project" `
    -Zone "us-central1-a" `
    -Name "my-instance" `
    -MachineType "n1-standard-1" `
    -DiskImage "projects/debian-cloud/global/images/family/debian-11"

# Create with custom configuration
$diskConfig = New-GceAttachedDiskConfig `
    -SourceImage "projects/ubuntu-os-cloud/global/images/family/ubuntu-2004-lts" `
    -DiskType "pd-ssd" `
    -DiskSizeGb 100

New-GceInstance `
    -Project "my-project" `
    -Zone "us-central1-a" `
    -Name "my-custom-vm" `
    -MachineType "n1-standard-4" `
    -Disk $diskConfig `
    -Tag "http-server","https-server" `
    -Metadata @{"startup-script" = "apt-get update && apt-get install -y nginx"}
```

### Manage VMs

```powershell
# Get instances
Get-GceInstance -Project "my-project" -Zone "us-central1-a"

# Start instance
Start-GceInstance -Project "my-project" -Zone "us-central1-a" -Name "my-instance"

# Stop instance
Stop-GceInstance -Project "my-project" -Zone "us-central1-a" -Name "my-instance"

# Remove instance
Remove-GceInstance -Project "my-project" -Zone "us-central1-a" -Name "my-instance"
```

### Bulk Operations

```powershell
# Stop all running instances in a zone
Get-GceInstance -Project "my-project" -Zone "us-central1-a" |
    Where-Object {$_.Status -eq "RUNNING"} |
    Stop-GceInstance

# Get instances by tag
Get-GceInstance -Project "my-project" |
    Where-Object {$_.Tags.Items -contains "webserver"}
```

## Object-Oriented PowerShell Benefits

```powershell
# Rich object pipeline
Get-GceInstance -Project "my-project" |
    Where-Object {$_.Status -eq "RUNNING"} |
    Select-Object Name, Zone, MachineType, Status |
    Format-Table

# Complex filtering
Get-GceInstance -Project "my-project" |
    Where-Object {
        $_.Status -eq "RUNNING" -and
        $_.MachineType -like "*n1-standard*"
    } |
    ForEach-Object {
        Stop-GceInstance -Instance $_
    }
```

## GCE Best Practices

- **Cost Management**:

  - Use preemptible VMs for batch workloads
  - Stop instances when not in use
  - Right-size machine types
  - Use committed use discounts

- **Security**:

  - Use service accounts with least privilege
  - Enable OS Login
  - Implement firewall rules
  - Use Shielded VMs
  - Regular patching

- **Automation**:

  - Use instance templates
  - Leverage managed instance groups
  - Implement health checks
  - Automate startup scripts

- **Monitoring**:
  - Enable Cloud Monitoring
  - Set up alerting
  - Monitor resource utilization
  - Track costs

## Error Handling

Scripts include:

- Project and zone validation
- Instance existence checks
- Quota validation
- Status verification
- Comprehensive error messages

## Related Documentation

- [Google Cloud PowerShell](https://github.com/GoogleCloudPlatform/google-cloud-powershell)
- [GCE Documentation](https://cloud.google.com/compute/docs)
- [PowerShell Module Reference](https://googlecloudplatform.github.io/google-cloud-powershell/)

## Support

For issues or questions, please refer to the main repository documentation.
