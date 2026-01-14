# Google Cloud Engine (GCE) CLI Automation Scripts

This directory contains PowerShell scripts that automate Google Cloud Platform
operations using the gcloud CLI. All scripts are designed to be standalone,
modular, and follow consistent patterns for parameter validation and error
handling.

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
gcloud auth activate-service-account --key-file=path/to/service-account.json

# Application default credentials
gcloud auth application-default login
```

## Directory Structure

| Folder           | Description        | Service Focus                  |
| ---------------- | ------------------ | ------------------------------ |
| [`vms/`](./vms/) | Compute Engine VMs | Instance management, templates |

### Standalone Scripts

| Script                           | Description     | Use Case        |
| -------------------------------- | --------------- | --------------- |
| `gce-cli-delete-running-vms.ps1` | Bulk VM cleanup | Cost management |

## Common Usage Patterns

### Google Cloud CLI Verification

Scripts verify gcloud CLI installation and authentication:

```powershell
# Check gcloud CLI installation
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    throw "Google Cloud CLI is not installed or not in PATH"
}

# Verify authentication
$gcloudAuth = gcloud auth list --filter=status:ACTIVE --format="value(account)"
if (-not $gcloudAuth) {
    throw "Not authenticated with Google Cloud. Run 'gcloud auth login'"
}
```

### Parameter Validation

All scripts use PowerShell validation:

```powershell
[ValidateSet("us-central1-a", "us-west1-b", "europe-west1-c")]
[string]$Zone

[ValidatePattern('^[a-z][-a-z0-9]{0,61}[a-z0-9]$')]
[string]$InstanceName

[ValidateSet("e2-micro", "n1-standard-1", "n2-standard-2")]
[string]$MachineType
```

### Error Handling

Scripts implement comprehensive error handling:

```powershell
$ErrorActionPreference = 'Stop'
try {
    $result = gcloud compute instances create $InstanceName `
              --zone=$Zone --machine-type=$MachineType `
              --format=json | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        throw "gcloud command failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    exit 1
}
```

## Quick Start Examples

### Delete Running VMs

```powershell
.\gce-cli-delete-running-vms.ps1 `
  -ProjectId "my-project" `
  -Zone "us-central1-a" `
  -Force
```

### Create VM Instance

```powershell
.\vms\gce-cli-create-instance.ps1 `
  -InstanceName "my-instance" `
  -Zone "us-central1-a" `
  -MachineType "e2-medium" `
  -ProjectId "my-project"
```

## Security Considerations

1. **Service Accounts**: Use service accounts for automation scenarios
1. **IAM Roles**: Ensure minimal required permissions
1. **Resource Labels**: Apply consistent labels for organization
1. **Network Security**: Configure firewalls and VPC settings appropriately

## Best Practices

1. **Project Organization**: Use consistent project and resource naming
1. **Zone Selection**: Consider latency and availability requirements
1. **Resource Cleanup**: Always clean up test resources to manage costs
1. **Quota Management**: Monitor and plan for resource quotas
1. **Documentation**: Include comprehensive help in all scripts

## Troubleshooting

### Common Issues

1. **gcloud CLI Not Found**

   ```text
   gcloud : The term 'gcloud' is not recognized
   ```

   - Solution: Install Google Cloud SDK and ensure it's in your PATH

1. **Not Authenticated**

   ```text
   You do not currently have an active account selected
   ```

   - Solution: Run `gcloud auth login` to authenticate

1. **Project Not Set**

   ```text
   You must specify a project ID
   ```

   - Solution: Set project with `gcloud config set project PROJECT_ID`

1. **Quota Exceeded**

   ```text
   Quota exceeded for resource
   ```

   - Solution: Check quotas and request increases if needed

1. **Zone Not Available**

   ```text
   Zone does not exist or is not available
   ```

   - Solution: Check available zones with `gcloud compute zones list`

## Script Features

### Common Parameters

Most scripts support these standard parameters:

- `ProjectId`: Google Cloud project ID
- `Zone`: Compute zone for resources
- `Region`: Compute region for regional resources
- `Force`: Skip confirmation prompts
- `WhatIf`: Preview operations without executing
- `Labels`: Resource labels as hashtable

### Resource Management

- Automatic project validation
- Consistent resource naming and labeling
- Cleanup procedures for failed operations

### Output Formats

Scripts support multiple output formats:

- Console output with progress indicators
- JSON output for automation integration
- CSV export for reporting

## gcloud CLI Configuration

Essential configuration commands:

```bash
# Set default project
gcloud config set project PROJECT_ID

# Set default zone
gcloud config set compute/zone ZONE

# Set default region
gcloud config set compute/region REGION

# List current configuration
gcloud config list
```

## Resource Naming

Follow Google Cloud naming conventions:

- Use lowercase letters, numbers, and hyphens
- Start with a letter and end with a letter or number
- Keep names under 63 characters
- Use consistent naming patterns across resources

## Contributing

When adding new scripts:

1. Follow established parameter validation patterns
1. Include gcloud CLI availability checks
1. Add comprehensive error handling
1. Include detailed help documentation with examples
1. Test across multiple GCP zones and regions
1. Update this README with new script descriptions

## Cost Management

- Use preemptible instances for cost savings when appropriate
- Implement automated cleanup for temporary resources
- Monitor resource usage and set up billing alerts
- Use sustained use discounts for long-running workloads

## Support

For issues or questions:

1. Check individual script help documentation
1. Review Google Cloud CLI documentation
1. Consult GCP service documentation for limitations
1. Verify GCP permissions and quotas
