# AWS PowerShell - WorkSpaces Scripts

This directory contains PowerShell scripts for managing Amazon WorkSpaces using AWS Tools for PowerShell.

## Prerequisites

- AWS Tools for PowerShell installed (`Install-Module -Name AWS.Tools.WorkSpaces`)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`Set-AWSCredential` or AWS credential file)
- Appropriate IAM permissions for WorkSpaces operations
- WorkSpaces directory already configured

## Available Scripts

PowerShell cmdlets for WorkSpaces management:

- `New-WKSWorkspace` - Create WorkSpaces
- `Get-WKSWorkspace` - List and describe WorkSpaces
- `Remove-WKSWorkspace` - Terminate WorkSpaces
- `Restart-WKSWorkspace` - Reboot WorkSpaces
- `Reset-WKSWorkspace` - Rebuild WorkSpaces
- `Edit-WKSWorkspaceProperties` - Modify properties
- `Edit-WKSWorkspaceState` - Change running state

## Usage Examples

### Create a WorkSpace

```powershell
# Set credentials
Set-AWSCredential -ProfileName default -Region us-east-1

# Create WorkSpace
$workspace = New-WKSWorkspace `
    -DirectoryId d-1234567890 `
    -UserName "john.doe" `
    -BundleId wsb-12345678 `
    -VolumeEncryptionKey "alias/aws/workspaces" `
    -UserVolumeEncryptionEnabled $true `
    -RootVolumeEncryptionEnabled $true
```

### List WorkSpaces with Filtering

```powershell
# Get all WorkSpaces in AVAILABLE state
Get-WKSWorkspace |
    Where-Object {$_.State -eq 'AVAILABLE'} |
    Select-Object WorkspaceId, UserName, ComputerName, State
```

### Modify WorkSpace Properties

```powershell
# Change to AUTO_STOP mode
$properties = New-Object Amazon.WorkSpaces.Model.WorkspaceProperties
$properties.RunningMode = [Amazon.WorkSpaces.RunningMode]::AUTO_STOP
$properties.RunningModeAutoStopTimeoutInMinutes = 60

Edit-WKSWorkspaceProperties `
    -WorkspaceId ws-1234567890 `
    -WorkspaceProperties $properties
```

### Bulk Operations

```powershell
# Reboot all WorkSpaces for a specific user
Get-WKSWorkspace |
    Where-Object {$_.UserName -eq 'john.doe'} |
    ForEach-Object {
        Restart-WKSWorkspace -WorkspaceId $_.WorkspaceId
    }
```

## Object-Oriented Advantages

PowerShell returns rich .NET objects:

```powershell
# Get WorkSpace and access properties directly
$ws = Get-WKSWorkspace -WorkspaceId ws-1234567890

# Access nested properties
Write-Host "User: $($ws.UserName)"
Write-Host "Bundle: $($ws.BundleId)"
Write-Host "State: $($ws.State)"
Write-Host "IP: $($ws.IpAddress)"
Write-Host "Directory: $($ws.DirectoryId)"
```

## WorkSpaces Best Practices

- **Cost Optimization**:

  - Use AUTO_STOP for intermittent users
  - ALWAYS_ON for 24/7 users (more cost-effective if >80 hours/month)
  - Monitor and terminate unused WorkSpaces

- **Security**:

  - Enable volume encryption for all WorkSpaces
  - Use MFA for sensitive environments
  - Implement security groups for network control
  - Regular patching through image updates

- **Management**:
  - Use tags for organization and cost tracking
  - Create custom bundles for standardization
  - Implement automated backup strategies
  - Monitor connection health metrics

## Error Handling

Scripts include:

- Parameter validation with proper types
- Try-catch blocks for AWS operations
- State verification before operations
- Comprehensive error messages

## Related Documentation

- [AWS Tools for PowerShell - WorkSpaces Cmdlets](https://docs.aws.amazon.com/powershell/latest/reference/items/WorkSpaces_cmdlets.html)
- [Amazon WorkSpaces Documentation](https://docs.aws.amazon.com/workspaces/)
- [AWS Tools for PowerShell Documentation](https://docs.aws.amazon.com/powershell/)

## Support

For issues or questions, please refer to the main repository documentation.
