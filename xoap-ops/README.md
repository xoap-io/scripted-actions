# XOAP Operations Scripts

This directory contains PowerShell scripts for XOAP-specific operations across multiple cloud platforms.

## Prerequisites

- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Appropriate cloud CLI tools installed (AWS CLI, Azure CLI, GCP CLI)
- Cloud PowerShell modules as needed (AWS.Tools, Az, GoogleCloud)
- Authenticated to respective cloud platforms
- XOAP platform access and credentials

## Available Scripts

### Multi-Cloud VM Termination

- **aws-cli-terminate-vms.ps1** - Terminate AWS EC2 instances (CLI)
- **aws-ps-terminate-vms.ps1** - Terminate AWS EC2 instances (PowerShell)
- **az-ps-terminate-vms.ps1** - Terminate Azure VMs
- **gce-ps-stop-vms.ps1** - Stop Google Cloud VMs
- **gce-cli-stop-vms.ps1** - Bulk stop all running GCE instances in a
  project using `gcloud compute instances stop`; supports zone filtering,
  WhatIf, confirmation prompt, post-verification, and timestamped logging
- **nutanix-cli-stop-vms.ps1** - Bulk stop all running Nutanix VMs via
  Prism Central v3 REST API (ACPI shutdown with power_off fallback);
  supports cluster filtering, WhatIf, confirmation prompt,
  post-verification, and timestamped logging

### Azure Image Management

- **az-ps-delete-image-revisions.ps1** - Clean up old Azure VM image versions
- **az-ps-delete-image-gallery-revisions.ps1** - Manage Azure Compute Gallery versions

## Usage Examples

### AWS VM Termination (CLI)

```powershell
# Terminate specific EC2 instances
.\aws-cli-terminate-vms.ps1 -InstanceIds "i-1234567890abcdef0","i-0987654321fedcba0" -Region "us-east-1"

# Terminate instances by tag
.\aws-cli-terminate-vms.ps1 -TagKey "Environment" -TagValue "Test" -Region "us-east-1"
```

### AWS VM Termination (PowerShell)

```powershell
# Using AWS.Tools PowerShell module
.\aws-ps-terminate-vms.ps1 -InstanceIds "i-1234567890abcdef0","i-0987654321fedcba0" -Region "us-east-1"
```

### Azure VM Termination

```powershell
# Terminate Azure VMs
.\az-ps-terminate-vms.ps1 -ResourceGroupName "XOAP-Test-RG" -VMNames "TestVM01","TestVM02"

# Terminate all VMs in resource group
.\az-ps-terminate-vms.ps1 -ResourceGroupName "XOAP-Test-RG" -All
```

### Azure Image Cleanup

```powershell
# Delete old image revisions, keep latest 3
.\az-ps-delete-image-revisions.ps1 `
    -ResourceGroupName "Images-RG" `
    -GalleryName "MyGallery" `
    -ImageDefinition "Windows10-Enterprise" `
    -KeepLatest 3

# Delete specific version
.\az-ps-delete-image-revisions.ps1 `
    -ResourceGroupName "Images-RG" `
    -GalleryName "MyGallery" `
    -ImageDefinition "Windows10-Enterprise" `
    -Version "1.0.0"
```

### GCP VM Operations

```powershell
# Stop GCE instances
.\gce-ps-stop-vms.ps1 -Project "my-project" -Zone "us-central1-a" -InstanceNames "instance1","instance2"
```

## XOAP Operations Best Practices

- **Automation Safety**:

  - Always test in non-production first
  - Implement confirmation prompts
  - Log all operations
  - Use tags/labels for resource identification
  - Implement rollback procedures

- **Cost Management**:

  - Regular cleanup of unused resources
  - Remove old image versions
  - Terminate non-production VMs after hours
  - Monitor cloud spending
  - Implement resource tagging

- **Multi-Cloud**:

  - Consistent naming conventions
  - Unified tagging strategy
  - Centralized logging
  - Standard operating procedures
  - Documentation of differences

- **Security**:
  - Use service accounts/managed identities
  - Implement least privilege
  - Audit logging enabled
  - Secure credential storage
  - Regular access reviews

## Multi-Cloud Tagging Strategy

### AWS Tags

```powershell
Environment = "Production|Test|Development"
Project = "ProjectName"
CostCenter = "CC-1234"
ManagedBy = "XOAP"
AutoShutdown = "Yes|No"
```

### Azure Tags

```powershell
Environment = "Production|Test|Development"
Project = "ProjectName"
CostCenter = "CC-1234"
ManagedBy = "XOAP"
AutoShutdown = "Yes|No"
```

### GCP Labels

```powershell
environment = "production|test|development"
project = "project-name"
cost-center = "cc-1234"
managed-by = "xoap"
auto-shutdown = "yes|no"
```

## Bulk Operations Considerations

- **Rate Limiting**: Be aware of API rate limits
- **Batch Size**: Process resources in manageable batches
- **Error Handling**: Implement retry logic
- **Logging**: Detailed operation logs
- **Notifications**: Alert on failures
- **Scheduling**: Use appropriate scheduling for maintenance windows

## Cost Optimization Strategies

### Image Management

- Delete old, unused image versions
- Keep only necessary versions
- Use lifecycle policies
- Regular cleanup schedules

### VM Management

- Auto-shutdown of non-production VMs
- Right-sizing recommendations
- Reserved instances for production
- Spot/preemptible for batch workloads

## Error Handling

Scripts include:

- Cloud platform connectivity checks
- Resource existence validation
- Permission verification
- Batch operation error handling
- Comprehensive logging
- Rollback capabilities where applicable

## Related Documentation

- [XOAP Platform Documentation](https://xoap.io/docs)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/)
- [Azure CLI Reference](https://docs.microsoft.com/cli/azure/)
- [GCP CLI Reference](https://cloud.google.com/sdk/gcloud/reference)

## Support

For XOAP-specific issues, contact XOAP support.
For general script issues, please refer to the main repository documentation.
