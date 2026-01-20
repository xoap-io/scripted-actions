# AWS CLI - Security Scripts

This directory contains PowerShell scripts for managing AWS security services using the AWS CLI.

## Prerequisites

- AWS CLI v2.16+ installed and configured
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured with appropriate security permissions
- IAM permissions for security services (IAM, Secrets Manager, KMS, etc.)

## Available Scripts

### IAM Management

- **aws-cli-create-iam-role.ps1** - Creates IAM roles with trust policies
- **aws-cli-create-iam-user.ps1** - Creates IAM users
- **aws-cli-attach-iam-policy.ps1** - Attaches policies to roles or users
- **aws-cli-list-iam-roles.ps1** - Lists IAM roles
- **aws-cli-list-iam-users.ps1** - Lists IAM users

### Secrets Manager

- **aws-cli-create-secret.ps1** - Creates secrets in AWS Secrets Manager
- **aws-cli-get-secret-value.ps1** - Retrieves secret values
- **aws-cli-update-secret.ps1** - Updates existing secrets
- **aws-cli-delete-secret.ps1** - Deletes secrets

### AWS KMS (Key Management Service)

- **aws-cli-create-kms-key.ps1** - Creates KMS customer master keys
- **aws-cli-encrypt-data.ps1** - Encrypts data using KMS
- **aws-cli-decrypt-data.ps1** - Decrypts data using KMS

### Security Groups

- **aws-cli-create-security-group.ps1** - Creates EC2 security groups
- **aws-cli-add-security-group-rule.ps1** - Adds ingress/egress rules
- **aws-cli-remove-security-group-rule.ps1** - Removes rules

## Usage Examples

### Create an IAM Role

```powershell
.\aws-cli-create-iam-role.ps1 `
    -RoleName "EC2-S3-Access" `
    -TrustPolicy "ec2-trust-policy.json" `
    -Description "Allows EC2 instances to access S3"
```

### Create a Secret

```powershell
.\aws-cli-create-secret.ps1 `
    -SecretName "prod/database/password" `
    -SecretString "MySecurePassword123!" `
    -Description "Production database password"
```

### Retrieve a Secret

```powershell
.\aws-cli-get-secret-value.ps1 -SecretId "prod/database/password"
```

### Create a KMS Key

```powershell
.\aws-cli-create-kms-key.ps1 `
    -Description "Encryption key for S3 buckets" `
    -KeyUsage ENCRYPT_DECRYPT
```

## Security Best Practices

- **IAM**:

  - Follow principle of least privilege
  - Use roles instead of long-term credentials
  - Enable MFA for privileged users
  - Regularly rotate access keys

- **Secrets Management**:

  - Enable automatic rotation for secrets
  - Use resource-based policies for access control
  - Never hardcode secrets in scripts
  - Use IAM policies to restrict secret access

- **Encryption**:
  - Use KMS for encryption at rest
  - Enable encryption in transit (TLS/SSL)
  - Regularly rotate encryption keys
  - Use separate keys for different data classifications

## Error Handling

All scripts include:

- IAM entity validation
- Permission checks
- Secret format validation
- Comprehensive error messages
- Audit logging recommendations

## Related Documentation

- [AWS IAM Documentation](https://docs.aws.amazon.com/iam/)
- [AWS Secrets Manager Documentation](https://docs.aws.amazon.com/secretsmanager/)
- [AWS KMS Documentation](https://docs.aws.amazon.com/kms/)
- [AWS CLI Command Reference - IAM](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/iam/index.html)

## Support

For issues or questions, please refer to the main repository documentation.
