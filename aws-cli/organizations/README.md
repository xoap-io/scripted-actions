# AWS CLI - Organizations Scripts

This directory contains PowerShell scripts for managing AWS Organizations using the AWS CLI.

## Prerequisites

- AWS CLI v2.16+ installed and configured
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials with Organizations management permissions
- Must be run from the organization's management account

## Available Scripts

### Account Management

- **aws-cli-create-account.ps1** - Creates new AWS accounts in the organization
- **aws-cli-list-accounts.ps1** - Lists all accounts in the organization
- **aws-cli-describe-account.ps1** - Retrieves detailed account information
- **aws-cli-remove-account.ps1** - Removes accounts from the organization
- **aws-cli-invite-account.ps1** - Invites existing accounts to join organization
- **aws-cli-move-account.ps1** - Moves accounts between organizational units

### Organizational Unit (OU) Management

- **aws-cli-create-organizational-unit.ps1** - Creates organizational units
- **aws-cli-list-organizational-units.ps1** - Lists OUs in the organization
- **aws-cli-delete-organizational-unit.ps1** - Deletes organizational units

### Policy Management

- **aws-cli-list-policies.ps1** - Lists service control policies
- **aws-cli-attach-policy.ps1** - Attaches policies to OUs or accounts
- **aws-cli-detach-policy.ps1** - Detaches policies from OUs or accounts

## Usage Examples

### Create a New Account

```powershell
.\aws-cli-create-account.ps1 `
    -AccountName "Development" `
    -Email "dev-account@example.com" `
    -RoleName "OrganizationAccountAccessRole"
```

### List All Accounts

```powershell
.\aws-cli-list-accounts.ps1
```

### Create an Organizational Unit

```powershell
.\aws-cli-create-organizational-unit.ps1 `
    -Name "Production" `
    -ParentId r-abcd
```

### Move Account to OU

```powershell
.\aws-cli-move-account.ps1 `
    -AccountId 123456789012 `
    -SourceParentId ou-old-12345 `
    -DestinationParentId ou-new-67890
```

### Attach Policy

```powershell
.\aws-cli-attach-policy.ps1 `
    -PolicyId p-12345678 `
    -TargetId ou-abcd-12345678
```

## Organization Best Practices

- Use separate accounts for different environments (dev, staging, prod)
- Organize accounts into OUs by function or business unit
- Implement service control policies (SCPs) for governance
- Enable CloudTrail in the management account
- Use consolidated billing features
- Regular audit of account and policy configurations

## Security Considerations

- Management account should have minimal direct usage
- Use cross-account roles for access to member accounts
- Implement least-privilege SCPs
- Enable MFA for the management account root user
- Monitor organization activity with AWS CloudTrail

## Error Handling

All scripts include:

- Account ID and email validation
- Parent/OU existence checks
- Policy attachment validation
- Comprehensive error messages

## Related Documentation

- [AWS Organizations Documentation](https://docs.aws.amazon.com/organizations/)
- [AWS CLI Command Reference - Organizations](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/organizations/index.html)

## Support

For issues or questions, please refer to the main repository documentation.
