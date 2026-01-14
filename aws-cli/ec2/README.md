# AWS CLI - EC2 Scripts

This directory contains PowerShell scripts for managing Amazon EC2 (Elastic Compute Cloud) instances and related resources using the AWS CLI.

## Prerequisites

- AWS CLI v2.16+ installed and configured
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`aws configure`)
- Appropriate IAM permissions for EC2 operations

## Available Scripts

### Instance Management

- **aws-cli-create-ec2-instance.ps1** - Creates EC2 instances with specified configuration
- **aws-cli-describe-instances.ps1** - Lists and describes EC2 instances
- **aws-cli-get-instance-status.ps1** - Retrieves instance status information
- **aws-cli-get-instance-console-output.ps1** - Retrieves console output from instances
- **aws-cli-modify-instance-type.ps1** - Changes instance type
- **aws-cli-reboot-instances.ps1** - Reboots running instances
- **aws-cli-start-instances.ps1** - Starts stopped instances
- **aws-cli-stop-instances.ps1** - Stops running instances
- **aws-cli-terminate-instances.ps1** - Terminates instances

### AMI and Snapshots

- **aws-cli-create-ami-from-instance.ps1** - Creates Amazon Machine Images from instances
- **aws-cli-create-instance-snapshot.ps1** - Creates EBS volume snapshots
- **aws-cli-deregister-ami.ps1** - Deregisters AMIs

### Networking

- **aws-cli-allocate-elastic-ip.ps1** - Allocates Elastic IP addresses
- **aws-cli-associate-disassociate-elastic-ip.ps1** - Associates/disassociates Elastic IPs
- **aws-cli-create-security-group.ps1** - Creates security groups
- **aws-cli-delete-security-group.ps1** - Deletes security groups

### Storage

- **aws-cli-attach-detach-volume.ps1** - Attaches/detaches EBS volumes
- **aws-cli-create-ebs-volume.ps1** - Creates EBS volumes
- **aws-cli-delete-volume.ps1** - Deletes EBS volumes

### Key Pairs

- **aws-cli-create-ec2-key-pair.ps1** - Creates EC2 key pairs
- **aws-cli-delete-key-pair.ps1** - Deletes key pairs

### Advanced Features

- **aws-cli-attach-instance-profile.ps1** - Attaches IAM instance profiles
- **aws-cli-create-launch-template.ps1** - Creates launch templates
- **aws-cli-create-placement-group.ps1** - Creates placement groups
- **aws-cli-update-instance-metadata-options.ps1** - Updates instance metadata service options

## Usage Examples

### Create an EC2 Instance

```powershell
.\aws-cli-create-ec2-instance.ps1 `
    -AmiId ami-12345678 `
    -InstanceCount 1 `
    -InstanceType t3.micro `
    -KeyPairName myKeyPair `
    -SecurityGroupId sg-12345678 `
    -SubnetId subnet-12345678
```

### Stop an Instance

```powershell
.\aws-cli-stop-instances.ps1 -InstanceIds i-1234567890abcdef0
```

### Create an AMI

```powershell
.\aws-cli-create-ami-from-instance.ps1 `
    -InstanceId i-1234567890abcdef0 `
    -ImageName "MyCustomAMI" `
    -ImageDescription "Custom AMI for production"
```

## Common Parameters

Most scripts support the following common parameters:

- Region specification via AWS CLI configuration
- Instance IDs or resource IDs
- Tags for resource organization
- Verbose output with `-Verbose` flag

## Error Handling

All scripts include:

- Parameter validation with `[ValidateSet]` and `[ValidatePattern]`
- AWS CLI availability checks
- Comprehensive error messages
- Exit codes (0 = success, 1 = failure)

## Related Documentation

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS CLI Command Reference - EC2](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/ec2/index.html)

## Support

For issues or questions, please refer to the main repository documentation.
