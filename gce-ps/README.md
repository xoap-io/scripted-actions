# Google Cloud Engine (GCE) PowerShell Automation Scripts

This directory contains PowerShell scripts that automate Google Cloud Platform
operations using the Google.Cloud PowerShell modules and gcloud CLI integration.
All scripts are designed to be standalone and follow consistent patterns.

## Prerequisites

- **Google Cloud SDK**: Install from [Cloud SDK Documentation](https://cloud.google.com/sdk/docs/install)
- **PowerShell 5.1+**: Windows PowerShell or PowerShell Core
- **Google Cloud Project**: Valid GCP project with appropriate permissions

## Authentication

Scripts authenticate using gcloud CLI authentication:

```bash
# Interactive login
gcloud auth login

# Service account authentication
gcloud auth activate-service-account --key-file=service-account.json

# Application default credentials
gcloud auth application-default login
```

## Directory Structure

| Folder | Description | Service Focus |
|--------|-------------|---------------|
| [`vms/`](./vms/) | Compute Engine management | VM instances, templates, operations |

## Common Usage Patterns

### Google Cloud CLI Integration

Scripts verify gcloud CLI availability:

```powershell
# Check gcloud CLI installation
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    throw "Google Cloud CLI is not installed or not in PATH"
}

# Verify project configuration
$currentProject = gcloud config get-value project 2>$null
if (-not $currentProject) {
    throw "No default project set. Run 'gcloud config set project PROJECT_ID'"
}
```

### Parameter Validation

All scripts use comprehensive validation:

```powershell
[ValidateSet("us-central1-a", "us-west1-b", "europe-west1-c")]
[string]$Zone

[ValidatePattern('^[a-z][-a-z0-9]{0,61}[a-z0-9]$')]
[string]$InstanceName

[ValidateSet("e2-micro", "n1-standard-1", "n2-standard-2")]
[string]$MachineType
```

### Error Handling

Scripts implement robust error handling:

```powershell
$ErrorActionPreference = 'Stop'
try {
    $result = gcloud compute instances create $InstanceName `
              --zone=$Zone --machine-type=$MachineType `
              --format=json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        throw "Operation failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Error "GCP operation failed: $($_.Exception.Message)"
    exit 1
}
```

## Quick Start Examples

### VM Management

```powershell
# Create VM instance
.\vms\gce-ps-create-instance.ps1 `
  -InstanceName "my-vm" `
  -Zone "us-central1-a" `
  -MachineType "e2-medium" `
  -ProjectId "my-project"

# Start VM instance
.\vms\gce-ps-start-instance.ps1 `
  -InstanceName "my-vm" `
  -Zone "us-central1-a"

# Stop VM instance
.\vms\gce-ps-stop-instance.ps1 `
  -InstanceName "my-vm" `
  -Zone "us-central1-a"
```

## Security Considerations

1. **Service Account Keys**: Use service accounts with minimal permissions
1. **IAM Roles**: Follow principle of least privilege
1. **Network Security**: Configure VPC and firewall rules appropriately
1. **Resource Labels**: Apply consistent labels for governance

## Best Practices

1. **Project Organization**: Use clear project structure and naming
1. **Zone Selection**: Choose zones based on latency and availability needs
1. **Resource Cleanup**: Implement cleanup procedures for test resources
1. **Cost Optimization**: Use appropriate machine types and preemptible instances
1. **Documentation**: Include detailed help and examples in scripts

## Troubleshooting

### Common Issues

1. **gcloud CLI Not Found**

   ```text
   gcloud : The term 'gcloud' is not recognized
   ```

   - Solution: Install Google Cloud SDK and update PATH

1. **Authentication Required**

   ```text
   You do not currently have an active account selected
   ```

   - Solution: Run `gcloud auth login`

1. **Project Not Configured**

   ```text
   You must specify a project ID
   ```

   - Solution: Set project with `gcloud config set project PROJECT_ID`

1. **Insufficient Permissions**

   ```text
   The user does not have access to service account
   ```

   - Solution: Verify IAM roles and permissions

1. **Resource Quota Exceeded**

   ```text
   Quota 'CPUS' exceeded
   ```

   - Solution: Check quotas and request increases

## Script Features

### Common Parameters

Most scripts support these standard parameters:

- `ProjectId`: Google Cloud project ID
- `Zone`: Compute zone for resources
- `Region`: Compute region for regional resources
- `Force`: Skip confirmation prompts
- `WhatIf`: Preview operations without executing
- `Labels`: Resource labels for organization

### Resource Management

- Automatic project and zone validation
- Consistent resource naming conventions
- Error handling with cleanup procedures
- Progress reporting for long operations

### VM Management Features

- Instance lifecycle management (create, start, stop, delete)
- Custom machine type configuration
- Disk and network configuration
- Metadata and startup script support

## Google Cloud Configuration

Essential gcloud CLI configuration:

```bash
# Set default project
gcloud config set project PROJECT_ID

# Set default zone
gcloud config set compute/zone us-central1-a

# Set default region
gcloud config set compute/region us-central1

# Enable required APIs
gcloud services enable compute.googleapis.com
```

## Resource Naming Conventions

Follow Google Cloud naming best practices:

- Use lowercase letters, numbers, and hyphens only
- Start with a letter, end with letter or number
- Maximum 63 characters for most resources
- Use descriptive and consistent naming patterns

## Cost Management

- Monitor resource usage with Cloud Billing
- Use preemptible instances for batch workloads
- Set up budget alerts and quotas
- Implement automated resource cleanup
- Choose appropriate machine types for workloads

## Contributing

When adding new scripts:

1. Follow established parameter validation patterns
1. Include gcloud CLI dependency checks
1. Add comprehensive error handling
1. Include detailed help documentation with examples
1. Test across multiple GCP zones and projects
1. Update this README with new script descriptions

## Performance Considerations

- Use regional persistent disks for better performance
- Consider machine type and CPU platform selection
- Implement parallel operations for bulk tasks
- Use appropriate disk types (SSD vs HDD)

## Monitoring and Logging

- Enable Cloud Monitoring for resource metrics
- Configure Cloud Logging for audit trails
- Use labels for resource organization and billing
- Implement health checks for critical instances

## Support

For issues or questions:

1. Check individual script help documentation
1. Review Google Cloud CLI documentation
1. Consult GCP Compute Engine documentation
1. Verify project permissions and quotas
1. Check Google Cloud Status page for service issues
