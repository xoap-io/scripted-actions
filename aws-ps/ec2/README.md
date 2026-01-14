# AWS PowerShell - EC2 Scripts

This directory contains PowerShell scripts for managing Amazon EC2 instances using the AWS Tools for PowerShell.

## Prerequisites

- AWS Tools for PowerShell installed (`Install-Module -Name AWS.Tools.EC2`)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`Set-AWSCredential` or AWS credential file)
- Appropriate IAM permissions for EC2 operations

## Available Scripts

### Instance Management

Scripts for creating, managing, and terminating EC2 instances using native PowerShell cmdlets such as:

- `New-EC2Instance`
- `Get-EC2Instance`
- `Start-EC2Instance`
- `Stop-EC2Instance`
- `Remove-EC2Instance`

### Networking

- Elastic IP management
- Security group configuration
- Network interface operations

### Storage

- EBS volume management
- Snapshot operations
- AMI creation and management

### Advanced Features

- Launch templates
- Auto Scaling groups
- Instance metadata service configuration

## Usage Examples

### Create an EC2 Instance

```powershell
# Set credentials
Set-AWSCredential -ProfileName default

# Create instance using AWS PowerShell cmdlets
.\aws-ps-create-ec2-instance.ps1 `
    -ImageId ami-12345678 `
    -InstanceType t3.micro `
    -KeyName mykey `
    -SecurityGroupId sg-12345678 `
    -SubnetId subnet-12345678
```

### Manage Elastic IPs

```powershell
.\aws-ps-allocate-elastic-ip.ps1 -Domain vpc
```

### Create an AMI

```powershell
.\aws-ps-create-ami.ps1 `
    -InstanceId i-1234567890abcdef0 `
    -Name "MyCustomAMI" `
    -Description "Custom AMI for production"
```

## Advantages of PowerShell Module vs CLI

- **Object-Oriented**: Work with .NET objects instead of JSON strings
- **Pipeline Support**: Leverage PowerShell's pipeline for complex operations
- **Type Safety**: Strong typing and IntelliSense support
- **Integration**: Better integration with Windows environments
- **Automation**: Easier to build complex automation workflows

## Common Patterns

### Using Pipeline

```powershell
# Get all stopped instances and start them
Get-EC2Instance |
    Where-Object {$_.State.Name -eq 'stopped'} |
    Start-EC2Instance
```

### Error Handling

```powershell
try {
    $instance = New-EC2Instance -ImageId ami-12345678
}
catch {
    Write-Error "Failed to create instance: $_"
}
```

## Error Handling

All scripts include:

- Parameter validation with proper types
- Try-catch blocks for AWS operations
- Comprehensive error messages
- Exit codes (0 = success, 1 = failure)

## Related Documentation

- [AWS Tools for PowerShell Documentation](https://docs.aws.amazon.com/powershell/)
- [AWS Tools for PowerShell - EC2 Cmdlets](https://docs.aws.amazon.com/powershell/latest/reference/items/EC2_cmdlets.html)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)

## Support

For issues or questions, please refer to the main repository documentation.
