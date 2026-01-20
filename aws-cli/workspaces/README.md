# AWS CLI - WorkSpaces Scripts

This directory contains PowerShell scripts for managing Amazon WorkSpaces using the AWS CLI.

## Prerequisites

- AWS CLI v2.16+ installed and configured
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`aws configure`)
- Appropriate IAM permissions for WorkSpaces operations
- WorkSpaces directory already configured in target region

## Available Scripts

### WorkSpace Management

- **aws-cli-create-workspace.ps1** - Provisions new WorkSpaces for users
- **aws-cli-describe-workspaces.ps1** - Lists and describes WorkSpaces
- **aws-cli-terminate-workspace.ps1** - Terminates WorkSpaces
- **aws-cli-reboot-workspace.ps1** - Reboots running WorkSpaces
- **aws-cli-rebuild-workspace.ps1** - Rebuilds WorkSpaces to original state
- **aws-cli-modify-workspace-properties.ps1** - Modifies WorkSpace properties
- **aws-cli-modify-workspace-state.ps1** - Changes WorkSpace running state

### Bundle and Image Management

- **aws-cli-describe-workspace-bundles.ps1** - Lists available WorkSpace bundles
- **aws-cli-create-workspace-bundle.ps1** - Creates custom WorkSpace bundles
- **aws-cli-create-workspace-image.ps1** - Creates custom WorkSpace images
- **aws-cli-delete-workspace-image.ps1** - Deletes custom images
- **aws-cli-list-available-workspace-images.ps1** - Lists available images

### Directory Management

- **aws-cli-describe-workspace-directories.ps1** - Lists WorkSpace directories
- **aws-cli-list-workspace-directories.ps1** - Lists directory information
- **aws-cli-register-workspace-directory.ps1** - Registers directories for WorkSpaces

### Snapshot Management

- **aws-cli-describe-workspace-snapshots.ps1** - Lists WorkSpace snapshots
- **aws-cli-create-workspace-snapshot.ps1** - Creates WorkSpace snapshots

### Tagging and Migration

- **aws-cli-create-tag.ps1** - Adds tags to WorkSpaces
- **aws-cli-delete-tag.ps1** - Removes tags from WorkSpaces
- **aws-cli-migrate-workspace.ps1** - Migrates WorkSpaces between bundles

## Usage Examples

### Create a WorkSpace

```powershell
.\aws-cli-create-workspace.ps1 `
    -DirectoryId d-1234567890 `
    -Username "john.doe" `
    -BundleId wsb-12345678 `
    -VolumeEncryption Enabled
```

### List All WorkSpaces

```powershell
.\aws-cli-describe-workspaces.ps1
```

### Reboot a WorkSpace

```powershell
.\aws-cli-reboot-workspace.ps1 -WorkSpaceId ws-1234567890
```

### Create Custom Image

```powershell
.\aws-cli-create-workspace-image.ps1 `
    -WorkSpaceId ws-1234567890 `
    -ImageName "CustomWindows10Image" `
    -ImageDescription "Windows 10 with corporate applications"
```

### Modify WorkSpace Properties

```powershell
.\aws-cli-modify-workspace-properties.ps1 `
    -WorkSpaceId ws-1234567890 `
    -RunningMode AUTO_STOP `
    -RunningModeAutoStopTimeoutInMinutes 60
```

## WorkSpaces Best Practices

- **User Management**:

  - Use Active Directory integration
  - Implement least-privilege access
  - Regular user account audits

- **Cost Optimization**:

  - Use AUTO_STOP mode for non-24/7 users
  - Right-size bundles based on workload
  - Monitor and remove unused WorkSpaces
  - Use monthly billing for always-on users

- **Security**:

  - Enable volume encryption
  - Use security groups to control network access
  - Implement MFA for sensitive environments
  - Regular image updates and patching

- **Performance**:
  - Deploy WorkSpaces in regions close to users
  - Monitor connection health metrics
  - Use appropriate bundle sizes for workload

## Common Parameters

- **DirectoryId**: The directory identifier for WorkSpaces registration
- **BundleId**: The bundle identifier determining WorkSpace configuration
- **RunningMode**: ALWAYS_ON, AUTO_STOP, or MANUAL
- **VolumeEncryption**: Enabled or Disabled for root and user volumes

## Error Handling

All scripts include:

- Directory and bundle ID validation
- Username format validation
- WorkSpace state checks
- Quota limit checks
- Comprehensive error messages

## Related Documentation

- [Amazon WorkSpaces Documentation](https://docs.aws.amazon.com/workspaces/)
- [AWS CLI Command Reference - WorkSpaces](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/workspaces/index.html)
- [WorkSpaces Pricing](https://aws.amazon.com/workspaces/pricing/)

## Support

For issues or questions, please refer to the main repository documentation.
