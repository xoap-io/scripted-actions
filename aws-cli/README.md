# AWS CLI Automation Scripts

This directory contains PowerShell scripts that automate AWS operations using
the AWS CLI. All scripts are designed to be standalone, modular, and follow
consistent patterns for parameter validation and error handling.

## Prerequisites

- **AWS CLI v2**: Install from [AWS CLI Documentation](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- **PowerShell 5.1+**: Windows PowerShell or PowerShell Core
- **AWS Credentials**: Configured via `aws configure` or environment variables

## Authentication

Scripts authenticate using the AWS CLI's configured credentials. Ensure you
have valid AWS credentials configured:

```bash
aws configure
# or
aws configure sso
```

## Directory Structure

| Folder                               | Description                 | Service Focus                                         |
| ------------------------------------ | --------------------------- | ----------------------------------------------------- |
| [`ec2/`](./ec2/)                     | EC2 instance management     | Virtual machines, key pairs, security groups          |
| [`monitoring/`](./monitoring/)       | Monitoring and cost         | CloudWatch alarms, dashboards, budgets, Cost Explorer |
| [`network/`](./network/)             | VPC and networking          | VPCs, subnets, internet gateways, route tables        |
| [`organizations/`](./organizations/) | AWS Organizations           | Account management, organizational units, policies    |
| [`rds/`](./rds/)                     | RDS database management     | Database instances, snapshots, backups                |
| [`security/`](./security/)           | Security and access control | Security groups, NACLs, IAM, KMS, GuardDuty           |
| [`storage/`](./storage/)             | S3 and storage services     | Buckets, objects, lifecycle policies                  |
| [`workspaces/`](./workspaces/)       | Amazon WorkSpaces           | Virtual desktops, bundles, directories                |
| [`xoap/`](./xoap/)                   | XOAP-specific integrations  | Custom automation workflows                           |

## Common Usage Patterns

### Parameter Validation

All scripts use PowerShell's built-in validation:

```powershell
[ValidateSet("us-east-1", "us-west-2", "eu-west-1")]
[string]$Region

[ValidatePattern('^i-[0-9a-f]{8,17}$')]
[string]$InstanceId
```

### Error Handling

Scripts use strict error handling:

```powershell
$ErrorActionPreference = 'Stop'
try {
    # AWS CLI operations
}
catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    exit 1
}
```

### AWS CLI Integration

Scripts verify AWS CLI availability and configuration:

```powershell
# Check AWS CLI installation
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw "AWS CLI is not installed or not in PATH"
}

# Verify AWS credentials
$awsIdentity = aws sts get-caller-identity 2>$null
if ($LASTEXITCODE -ne 0) {
    throw "AWS credentials not configured"
}
```

## Quick Start Examples

### Create EC2 Instance

```powershell
.\ec2\aws-cli-create-ec2-instance.ps1 `
  -InstanceName "MyServer" `
  -InstanceType "t3.micro" `
  -Region "us-east-1"
```

### Create VPC with Subnets

```powershell
.\network\aws-cli-create-vpc.ps1 `
  -VpcName "MyVPC" `
  -CidrBlock "10.0.0.0/16" `
  -Region "us-east-1"

.\network\aws-cli-create-subnet.ps1 `
  -SubnetName "MySubnet" `
  -VpcId "vpc-12345678" `
  -CidrBlock "10.0.1.0/24"
```

### Manage Organizations

```powershell
.\organizations\aws-cli-create-account.ps1 `
  -AccountName "Development" `
  -Email "dev@company.com"
```

## Security Considerations

1. **Least Privilege**: Ensure AWS credentials have minimal required permissions
1. **Resource Tagging**: Scripts apply consistent tags for resource management
1. **Validation**: All inputs are validated before AWS API calls
1. **Audit Trail**: Operations are logged for compliance and troubleshooting

## Best Practices

1. **Test First**: Use AWS CLI dry-run options where available
1. **Resource Cleanup**: Always clean up test resources to avoid charges
1. **Region Awareness**: Specify regions explicitly to avoid confusion
1. **Error Recovery**: Scripts include error handling and rollback where possible
1. **Documentation**: Each script includes comprehensive help documentation

## Troubleshooting

### Common Issues

1. **AWS CLI Not Found**

   ```text
   aws : The term 'aws' is not recognized
   ```

   - Solution: Install AWS CLI and ensure it's in your PATH

1. **Credentials Not Configured**

   ```text
   Unable to locate credentials
   ```

   - Solution: Run `aws configure` or set up environment variables

1. **Permission Denied**

   ```text
   AccessDenied: User is not authorized
   ```

   - Solution: Verify IAM permissions for the required AWS services

1. **Resource Already Exists**

   ```text
   AlreadyExistsException
   ```

   - Solution: Use unique names or check existing resources first

## Script Documentation

Each script includes:

- **Synopsis**: Brief description of functionality
- **Description**: Detailed explanation of what the script does
- **Parameters**: All parameters with validation rules and examples
- **Examples**: Multiple usage scenarios
- **Notes**: Requirements, dependencies, and version information

## Contributing

When adding new scripts:

1. Follow the established parameter validation patterns
1. Include comprehensive error handling
1. Add detailed help documentation
1. Test with multiple AWS regions and scenarios
1. Update this README with new script descriptions

## Support

For issues or questions:

1. Check the individual script documentation
1. Review AWS CLI documentation for service-specific details
1. Consult AWS service documentation for API limitations
1. Verify IAM permissions for the target AWS services
