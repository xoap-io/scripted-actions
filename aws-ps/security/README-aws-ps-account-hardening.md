# AWS Account Hardening Script

## Overview

This PowerShell script provides comprehensive AWS account security hardening
aligned with the CIS AWS Foundations Benchmark v3.0.0 and AWS Security Hub
findings. It automates the implementation of security controls across multiple
AWS services to strengthen your accounts security.

## Features

The script addresses critical security findings and implements:

### Core Security Controls

- **Identity & Access Management (IAM)**
  - Hardware MFA enforcement for root user
  - IAM Access Analyzer deployment
  - Direct policy attachment remediation
  - Account contact information setup

- **CloudTrail Logging**
  - Multi-region CloudTrail configuration
  - CloudWatch Logs integration
  - Log file validation
  - KMS encryption
  - Object-level logging for S3

- **CloudWatch Monitoring**
  - Metric filters for security events
  - Security alerting via SNS
  - Log group retention policies

- **S3 Security**
  - Bucket encryption (SSE-S3/KMS)
  - Public access blocking
  - MFA delete (manual guidance)
  - Lifecycle policies
  - SSL enforcement

- **Network Security**
  - VPC Flow Logs
  - Security group auditing
  - VPC endpoints for ECR, SSM
  - Admin port restriction

- **Additional Services**
  - AWS Config service setup
  - GuardDuty runtime monitoring
  - Security Hub enablement
  - EBS default encryption

### Security Hub Findings Remediation

The script remediates specific Security Hub findings:

- **GuardDuty.7**: EKS Runtime Monitoring with automated agent management
- **GuardDuty.11**: GuardDuty Runtime Monitoring
- **GuardDuty.12**: ECS Runtime Monitoring
- **GuardDuty.13**: EC2 Runtime Monitoring
- **SSM.6**: CloudWatch logging for SSM Automation
- **EC2.55-58**: VPC endpoints for ECR API, Docker Registry, SSM, SSM Contacts
- **IAM.28**: IAM Access Analyzer external access analyzer
- **S3.20**: S3 MFA delete (manual guidance)
- **CIS controls**: Various CloudTrail, S3, and monitoring controls

## Prerequisites

- **PowerShell 5.1+** (PowerShell Core 7+ recommended)
- **AWS CLI v2** installed and configured
- **AWS credentials** with sufficient permissions
- **Windows, macOS, or Linux** environment

### Required AWS Permissions

The script requires extensive AWS permissions. Recommended approach:

- Use an administrative role or user
- Ensure permissions for: IAM, S3, CloudTrail, CloudWatch, Config, GuardDuty,
  Security Hub, EC2, VPC, SSM, ECR

## Parameters

### Mandatory Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `HomeRegion` | String | Primary AWS region for global services | `"eu-central-1"` |
| `SecurityEmail` | String | Email for security notifications | `"security@company.com"` |

### Optional Core Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `AccountAlias` | String | `"cis-hardened-account"` | AWS account alias |
| `TargetRegions` | String[] | `@("eu-central-1","eu-west-1","us-east-1")` | Regions to harden |
| `SecurityPhone` | String | `"+49-000-0000000"` | Security contact phone |
| `SecurityFirstName` | String | `"Security"` | Security contact first name |
| `SecurityLastName` | String | `"Team"` | Security contact last name |
| `SecurityTitle` | String | `"Security Lead"` | Security contact title |

### CloudTrail Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `TrailName` | String | `"cis-multi-region-trail"` | CloudTrail name |
| `TrailBucketName` | String | `""` (auto-generated) | S3 bucket for CloudTrail logs |
| `TrailKmsAlias` | String | `"alias/cis-cloudtrail"` | KMS key for CloudTrail encryption |
| `TrailEnableLogFileValidation` | Switch | `$false` | Enable log file validation |

### Config Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ConfigBucketName` | String | `""` (auto-generated) | S3 bucket for Config |
| `ConfigDeliveryFrequency` | String | `"One_Hour"` | Config delivery frequency |

### Security Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `EbsDefaultKmsAlias` | String | `"alias/cis-ebs-default"` | KMS key for EBS encryption |
| `FlowLogGroupPrefix` | String | `"/aws/vpc/flowlogs/cis"` | VPC Flow Logs prefix |
| `FlowLogRetentionDays` | Int | `365` | Flow log retention period |
| `AdminPorts` | Int[] | `@(22,3389)` | Administrative ports to secure |
| `SnsTopicName` | String | `"cis-security-alerts"` | SNS topic for alerts |

### Feature Toggles

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `EnableCloudWatchAlarms` | Switch | `$false` | Enable CloudWatch monitoring |
| `EnableInspector` | Switch | `$false` | Enable AWS Inspector |
| `EnableMacie` | Switch | `$false` | Enable Amazon Macie |
| `EnableGuardDutyRuntimeMonitoring` | Switch | `$false` | Enable GuardDuty runtime features |
| `EnableVpcEndpoints` | Switch | `$false` | Create VPC endpoints |
| `EnableS3Lifecycle` | Switch | `$false` | Configure S3 lifecycle policies |
| `EnforceS3RequireSSL` | Switch | `$false` | Enforce SSL for S3 buckets |
| `EnsureCloudTrailManagementSelectors` | Switch | `$false` | Ensure CloudTrail management events |
| `RemediateIamUserDirectPolicies` | Switch | `$false` | Remove direct IAM user policies |

### S3 Lifecycle Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `S3LifecycleTransitionDays` | Int | `90` | Days to transition to IA storage |
| `S3LifecycleExpirationDays` | Int | `2555` | Days to expire objects |

### Safety Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `DryRun` | Switch | `$false` | Preview changes without applying |

## Usage Examples

### Basic Usage

```powershell
# Minimal required parameters
.\aws-ps-account-hardening.ps1 -HomeRegion "eu-central-1" -SecurityEmail "security@company.com"
```

### Comprehensive Security Hardening

```powershell
# Full security hardening with all features
.\aws-ps-account-hardening.ps1 `
  -HomeRegion "eu-central-1" `
  -TargetRegions @("eu-central-1", "eu-west-1", "us-east-1") `
  -SecurityEmail "security@company.com" `
  -SecurityPhone "+1-555-123-4567" `
  -AccountAlias "my-secure-account" `
  -EnableCloudWatchAlarms `
  -EnableGuardDutyRuntimeMonitoring `
  -EnableVpcEndpoints `
  -EnableS3Lifecycle `
  -EnforceS3RequireSSL `
  -RemediateIamUserDirectPolicies
```

### Dry Run (Preview Mode)

```powershell
# Preview changes without applying them
.\aws-ps-account-hardening.ps1 `
  -HomeRegion "eu-central-1" `
  -SecurityEmail "security@company.com" `
  -DryRun
```

### Custom Configuration

```powershell
# Custom bucket names and KMS aliases
.\aws-ps-account-hardening.ps1 `
  -HomeRegion "eu-central-1" `
  -SecurityEmail "security@company.com" `
  -TrailName "company-audit-trail" `
  -TrailBucketName "company-cloudtrail-logs" `
  -TrailKmsAlias "alias/company-audit-key" `
  -ConfigBucketName "company-config-logs" `
  -EbsDefaultKmsAlias "alias/company-ebs-key" `
  -FlowLogRetentionDays 90 `
  -EnableCloudWatchAlarms
```

### Regional Deployment

```powershell
# Deploy to specific regions only
.\aws-ps-account-hardening.ps1 `
  -HomeRegion "us-east-1" `
  -TargetRegions @("us-east-1", "us-west-2") `
  -SecurityEmail "security@company.com" `
  -EnableCloudWatchAlarms
```

## Script Behavior

### What the Script Does

1. **Validates Prerequisites**: Checks AWS CLI installation and credentials
2. **Sets Account Information**: Configures account alias and security contacts
3. **Creates Security Infrastructure**
   - KMS keys for encryption
   - S3 buckets for logging
   - IAM roles and policies
   - SNS topics for alerts
4. **Configures Logging Services**:
   - CloudTrail with CloudWatch integration
   - AWS Config
   - VPC Flow Logs
5. **Enables Security Services**:
   - Security Hub
   - GuardDuty with runtime monitoring
   - IAM Access Analyzer
6. **Implements Security Controls**:
   - S3 bucket hardening
   - Network security
   - Monitoring and alerting
7. **Provides Manual Remediation Guidance**: For controls that cannot be automated

### Error Handling

The script includes comprehensive error handling:

- **Permission Checks**: Validates required permissions before operations
- **Graceful Failures**: Continues execution when possible, logs failures
- **Manual Remediation**: Provides specific guidance for manual steps
- **Rollback Safety**: Designed to be re-runnable

### Output and Logging

The script provides colored console output:

- **🔵 Blue ([+])**: Informational messages
- **🟡 Yellow ([!])**: Warnings and manual steps required
- **🔴 Red ([x])**: Errors

## Manual Remediation Required

Some security controls require manual intervention:

### Root User MFA

**Finding**: CIS 1.5/IAM.9
**Action**: Enable hardware MFA for root user
**URL**: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_mfa_enable_virtual.html

### S3 MFA Delete

**Finding**: CIS 2.1.2/S3.20
**Action**: Enable MFA delete for S3 buckets containing sensitive data
**URL**: https://docs.aws.amazon.com/AmazonS3/latest/userguide/MultiFactorAuthenticationDelete.html

## Security Considerations

### Permissions

- Run with least privilege necessary
- Use temporary credentials when possible
- Monitor script execution through CloudTrail

### Data Protection

- Script creates KMS keys for encryption
- Sensitive data is encrypted at rest
- Access logs are retained for compliance

### Cost Impact

- CloudWatch Logs incur storage costs
- KMS key usage has minimal cost
- Config and CloudTrail have per-event costs
- VPC endpoints have hourly charges

## Troubleshooting

### Common Issues

**AWS CLI Not Found**

```
Solution: Install AWS CLI v2 and ensure it's in your PATH
```

**Permission Denied**

```
Solution: Ensure your AWS credentials have sufficient permissions
Check: IAM policies include required actions
```

**Resource Already Exists**

```
Behavior: Script detects existing resources and updates them
Action: Review output for conflicts
```

**Region Not Supported**

```
Solution: Use supported AWS regions
Check: Service availability in target regions
```

### Debug Mode

Add `-Verbose` parameter for detailed output:
```powershell
.\aws-ps-account-hardening.ps1 -HomeRegion "eu-central-1" -SecurityEmail "security@company.com" -Verbose
```

## Version History

- **v1.0**: Initial CIS AWS Foundations implementation
- **v2.0**: Added Security Hub findings remediation
- **v2.1**: Enhanced GuardDuty runtime monitoring
- **v2.2**: Added SSM Automation logging and VPC endpoints

## Support

For issues and questions:

1. Check the troubleshooting section
2. Review AWS CloudTrail logs for API errors
3. Validate permissions and service limits
4. Consult AWS documentation for service-specific issues

## License

This script is provided as-is for educational and operational use.
Test thoroughly in non-production environments before production deployment.
