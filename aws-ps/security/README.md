# AWS PowerShell - Security Scripts

This directory contains PowerShell scripts for managing AWS security services using AWS Tools for PowerShell.

## Prerequisites

- AWS Tools for PowerShell installed:
  - `Install-Module -Name AWS.Tools.IdentityManagement` (IAM)
  - `Install-Module -Name AWS.Tools.SecretsManager`
  - `Install-Module -Name AWS.Tools.KeyManagementService` (KMS)
  - `Install-Module -Name AWS.Tools.SecurityToken` (STS)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`Set-AWSCredential` or AWS credential file)
- Appropriate IAM permissions for security operations

## Available Scripts

### IAM (Identity and Access Management)

PowerShell cmdlets for IAM management:

- `New-IAMRole` - Create IAM roles
- `New-IAMUser` - Create IAM users
- `New-IAMPolicy` - Create custom policies
- `Register-IAMRolePolicy` - Attach policies to roles
- `Get-IAMRole`, `Get-IAMUser`, `Get-IAMPolicy` - List resources

### AWS Secrets Manager

- `New-SECSecret` - Create secrets
- `Get-SECSecretValue` - Retrieve secret values
- `Update-SECSecret` - Update existing secrets
- `Remove-SECSecret` - Delete secrets
- `Restore-SECSecret` - Restore deleted secrets

### AWS KMS (Key Management Service)

- `New-KMSKey` - Create customer master keys
- `Invoke-KMSEncrypt` - Encrypt data
- `Invoke-KMSDecrypt` - Decrypt data
- `New-KMSAlias` - Create key aliases

### AWS STS (Security Token Service)

- `Use-STSRole` - Assume IAM roles
- `Get-STSSessionToken` - Get temporary credentials
- `Get-STSCallerIdentity` - Get current identity

## Usage Examples

### Create an IAM Role with PowerShell

```powershell
# Set credentials
Set-AWSCredential -ProfileName default

# Create trust policy
$trustPolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{
                Service = "ec2.amazonaws.com"
            }
            Action = "sts:AssumeRole"
        }
    )
} | ConvertTo-Json -Depth 5

# Create role
New-IAMRole `
    -RoleName "EC2-S3-ReadOnly" `
    -AssumeRolePolicyDocument $trustPolicy `
    -Description "Allows EC2 instances read-only access to S3"

# Attach managed policy
Register-IAMRolePolicy `
    -RoleName "EC2-S3-ReadOnly" `
    -PolicyArn "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
```

### Manage Secrets

```powershell
# Create a secret
$secretValue = @{
    username = "admin"
    password = "P@ssw0rd123!"
} | ConvertTo-Json

New-SECSecret `
    -Name "prod/database/credentials" `
    -SecretString $secretValue `
    -Description "Production database credentials"

# Retrieve secret
$secret = Get-SECSecretValue -SecretId "prod/database/credentials"
$credentials = $secret.SecretString | ConvertFrom-Json
```

### Use KMS for Encryption

```powershell
# Create KMS key
$key = New-KMSKey `
    -Description "Application data encryption key" `
    -KeyUsage ENCRYPT_DECRYPT

# Create alias
New-KMSAlias `
    -AliasName "alias/app-data-key" `
    -TargetKeyId $key.KeyMetadata.KeyId

# Encrypt data
$plaintext = "Sensitive data"
$plaintextBytes = [System.Text.Encoding]::UTF8.GetBytes($plaintext)
$encrypted = Invoke-KMSEncrypt -KeyId "alias/app-data-key" -Plaintext $plaintextBytes

# Decrypt data
$decrypted = Invoke-KMSDecrypt -CiphertextBlob $encrypted.CiphertextBlob
$decryptedText = [System.Text.Encoding]::UTF8.GetString($decrypted.Plaintext)
```

### Assume an IAM Role

```powershell
# Assume role for cross-account access
$roleCredentials = Use-STSRole `
    -RoleArn "arn:aws:iam::123456789012:role/CrossAccountRole" `
    -RoleSessionName "PowerShellSession"

# Use temporary credentials
Set-AWSCredential `
    -AccessKey $roleCredentials.Credentials.AccessKeyId `
    -SecretKey $roleCredentials.Credentials.SecretAccessKey `
    -SessionToken $roleCredentials.Credentials.SessionToken
```

## Security Best Practices

- **Credential Management**:

  - Never hardcode credentials in scripts
  - Use IAM roles for EC2 instances
  - Rotate credentials regularly
  - Use credential profiles for different environments

- **Least Privilege**:

  - Grant minimum required permissions
  - Use resource-based policies when possible
  - Regular audit of IAM policies

- **Secrets Management**:

  - Enable automatic rotation for secrets
  - Use resource policies to restrict access
  - Enable versioning for secrets
  - Use separate secrets per environment

- **Encryption**:
  - Use KMS for all sensitive data
  - Separate keys by data classification
  - Enable key rotation
  - Use grants for temporary access

## Object-Oriented Benefits

PowerShell modules return rich objects that can be:

- Piped to other cmdlets
- Filtered with `Where-Object`
- Sorted with `Sort-Object`
- Formatted with `Format-Table` or `Format-List`

Example:

```powershell
# Get all roles and filter
Get-IAMRoleList |
    Where-Object {$_.RoleName -like "*EC2*"} |
    Select-Object RoleName, CreateDate, Arn
```

## Error Handling

All scripts include:

- Try-catch blocks for AWS operations
- Parameter validation with proper types
- Policy JSON validation
- Comprehensive error messages

## Related Documentation

- [AWS Tools for PowerShell - IAM](https://docs.aws.amazon.com/powershell/latest/reference/items/IAM_cmdlets.html)
- [AWS Tools for PowerShell - Secrets Manager](https://docs.aws.amazon.com/powershell/latest/reference/items/SecretsManager_cmdlets.html)
- [AWS Tools for PowerShell - KMS](https://docs.aws.amazon.com/powershell/latest/reference/items/KeyManagementService_cmdlets.html)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

## Support

For issues or questions, please refer to the main repository documentation.
