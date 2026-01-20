# AWS PowerShell Automation Scripts

This directory contains PowerShell scripts that automate AWS operations using
the AWS.Tools PowerShell modules. All scripts are designed to be standalone,
modular, and follow consistent patterns for parameter validation and error
handling.

## Prerequisites

- **PowerShell 5.1+**: Windows PowerShell or PowerShell Core
- **AWS.Tools Modules**: Automatically installed by scripts when needed
- **AWS Credentials**: Configured via AWS credentials file or environment variables

## Authentication

Scripts authenticate using AWS PowerShell credential management:

```powershell
# Set default AWS credentials
Set-AWSCredential -AccessKey "your-access-key" -SecretKey "your-secret-key"

# Or use profiles
Set-AWSCredential -ProfileName "default"

# Or use IAM roles (when running on EC2)
```

## Directory Structure

| Folder                         | Description              | Service Focus                     |
| ------------------------------ | ------------------------ | --------------------------------- |
| [`appstream/`](./appstream/)   | AppStream 2.0 management | Virtual application streaming     |
| [`ec2/`](./ec2/)               | EC2 instance management  | Virtual machines, security groups |
| [`nice-dcv/`](./nice-dcv/)     | NICE DCV integration     | Remote desktop sessions           |
| [`rds/`](./rds/)               | RDS database management  | Database instances and operations |
| [`workspaces/`](./workspaces/) | Amazon WorkSpaces        | Virtual desktop management        |

## Common Usage Patterns

### Module Installation

Scripts automatically install required AWS.Tools modules:

```powershell
function Test-AWSModule {
    param($ModuleName)

    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        Write-Host "Installing $ModuleName..." -ForegroundColor Yellow
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser
    }
    Import-Module $ModuleName -Force
}
```

### Parameter Validation

All scripts use comprehensive validation:

```powershell
[ValidateSet("us-east-1", "us-west-2", "eu-west-1")]
[string]$Region

[ValidatePattern('^i-[0-9a-f]{8,17}$')]
[string]$InstanceId

[ValidateRange(1, 100)]
[int]$InstanceCount
```

### Error Handling

Scripts implement robust error handling:

```powershell
$ErrorActionPreference = 'Stop'
try {
    # AWS PowerShell operations
    $result = Get-EC2Instance -InstanceId $InstanceId -Region $Region
}
catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    exit 1
}
```

## Quick Start Examples

### Create EC2 Instance

```powershell
.\ec2\aws-ps-create-ec2-instance.ps1 `
  -InstanceName "MyServer" `
  -InstanceType "t3.micro" `
  -Region "us-east-1" `
  -KeyPairName "my-keypair"
```

### Manage AppStream

```powershell
.\appstream\appstream-quickstart.ps1 `
  -FleetName "MyFleet" `
  -StackName "MyStack" `
  -Region "us-east-1" `
  -InstanceType "stream.standard.medium"
```

### WorkSpaces Management

```powershell
.\workspaces\aws-ps-create-workspace.ps1 `
  -DirectoryId "d-12345678" `
  -Username "testuser" `
  -BundleId "wsb-12345678" `
  -Region "us-east-1"
```

## Security Considerations

1. **Credential Management**: Use AWS credential profiles instead of hardcoded keys
1. **Resource Tagging**: All resources are tagged for management and billing
1. **Input Validation**: All parameters are validated before API calls
1. **Least Privilege**: Scripts assume minimal required permissions

## Best Practices

1. **Module Management**: Scripts handle AWS.Tools module installation automatically
1. **Region Specification**: Always specify AWS regions explicitly
1. **Error Recovery**: Include comprehensive error handling and cleanup
1. **Resource Cleanup**: Provide cleanup scripts for test resources
1. **Documentation**: Each script includes detailed help and examples

## Troubleshooting

### Common Issues

1. **Module Not Found**

   ```text
   Module 'AWS.Tools.EC2' not found
   ```

   - Solution: Scripts auto-install modules or run `Install-Module AWS.Tools.EC2`

1. **Credentials Not Set**

   ```text
   No credentials specified or found
   ```

   - Solution: Configure AWS credentials using `Set-AWSCredential`

1. **Region Not Specified**

   ```text
   No default region specified
   ```

   - Solution: Specify `-Region` parameter or set `Set-DefaultAWSRegion`

1. **Permission Denied**

   ```text
   User is not authorized to perform this operation
   ```

   - Solution: Verify IAM permissions for the AWS service

## Script Features

### Common Parameters

Most scripts support these standard parameters:

- `Region`: AWS region for operations
- `ProfileName`: AWS credential profile to use
- `Force`: Skip confirmation prompts
- `WhatIf`: Show what would be done without executing
- `Verbose`: Detailed operation logging

### Error Handling

- Automatic retry logic for transient failures
- Comprehensive error messages with suggested solutions
- Cleanup of partially created resources on failure

### Logging

- Detailed progress reporting
- Success/failure status for each operation
- Performance metrics for operations

## Contributing

When adding new scripts:

1. Follow the established parameter validation patterns
1. Include automatic module installation
1. Add comprehensive error handling with cleanup
1. Include detailed help documentation with examples
1. Test with multiple AWS regions and scenarios
1. Update this README with new script descriptions

## Module Dependencies

Common AWS.Tools modules used:

- `AWS.Tools.Common`: Core AWS functionality
- `AWS.Tools.EC2`: EC2 operations
- `AWS.Tools.AppStream`: AppStream 2.0 operations
- `AWS.Tools.WorkSpaces`: WorkSpaces operations
- `AWS.Tools.RDS`: RDS database operations

## Support

For issues or questions:

1. Check the individual script help documentation
1. Review AWS PowerShell documentation
1. Consult AWS service-specific PowerShell cmdlet reference
1. Verify AWS credentials and permissions
