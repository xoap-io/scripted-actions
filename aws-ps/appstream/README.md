# AWS PowerShell - AppStream 2.0 Scripts

This directory contains PowerShell scripts for managing Amazon AppStream 2.0 using the AWS Tools for PowerShell.

## Prerequisites

- AWS Tools for PowerShell installed (`Install-Module -Name AWS.Tools.AppStream`)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`Set-AWSCredential` or AWS credential file)
- Appropriate IAM permissions for AppStream 2.0 operations

## Available Scripts

Scripts in this directory manage AppStream 2.0 fleets, stacks, and streaming instances.

### Key Operations

- Fleet management (create, start, stop, delete)
- Stack management
- Image builder operations
- User access management
- Application catalog management

## Usage Examples

### Typical Workflow

```powershell
# Set AWS credentials
Set-AWSCredential -ProfileName myprofile

# Run scripts as needed
.\appstream-operation.ps1 -Parameter Value
```

## AppStream 2.0 Best Practices

- **Cost Management**:

  - Stop fleets when not in use
  - Use fleet auto-scaling
  - Choose appropriate instance types

- **Security**:

  - Use VPC endpoints for private connectivity
  - Implement application entitlements
  - Enable user data backup

- **Performance**:
  - Deploy fleets in regions close to users
  - Use SSD-backed instance types for better performance
  - Monitor streaming quality metrics

## Error Handling

Scripts include:

- Parameter validation
- AWS service availability checks
- Resource state verification
- Comprehensive error messages

## Related Documentation

- [Amazon AppStream 2.0 Documentation](https://docs.aws.amazon.com/appstream2/)
- [AWS Tools for PowerShell - AppStream](https://docs.aws.amazon.com/powershell/latest/reference/items/AppStream2_cmdlets.html)

## Support

For issues or questions, please refer to the main repository documentation.
