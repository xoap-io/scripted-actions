# Security Scripts

PowerShell scripts for AWS account-level security hardening and
remediation using AWS Tools for PowerShell and the AWS CLI.

## Prerequisites

- AWS Tools for PowerShell:
  - `Install-Module -Name AWS.Tools.EC2`
  - `Install-Module -Name AWS.Tools.CloudTrail`
  - `Install-Module -Name AWS.Tools.GuardDuty`
  - `Install-Module -Name AWS.Tools.SecurityHub`
  - `Install-Module -Name AWS.Tools.ConfigService`
  - `Install-Module -Name AWS.Tools.IdentityManagement`
- AWS CLI installed and configured (required by
  `aws-ps-account-unhardening.ps1`)
- Appropriate AWS credentials configured with administrative
  permissions

## Available Scripts

| Script                           | Description                                                                                                                                                                                  |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `aws-ps-account-hardening.ps1`   | Applies CIS AWS Foundations v3.0.0-aligned hardening: CloudTrail, GuardDuty, Security Hub, AWS Config, IAM password policy, VPC Flow Logs, EBS encryption, CloudWatch alarms, and SNS alerts |
| `aws-ps-account-unhardening.ps1` | Reverts hardening actions selectively via switches; intended for lab or teardown scenarios                                                                                                   |
| `aws-ps-create-iam-role.ps1`     | Creates an IAM role with a trust policy using `New-IAMRole`; supports tags, custom path, and max session duration                                                                            |
| `aws-ps-create-iam-policy.ps1`   | Creates a managed IAM policy using `New-IAMPolicy`; optionally attaches it to a role (`Register-IAMRolePolicy`) or user (`Register-IAMUserPolicy`)                                           |
| `aws-ps-enable-guardduty.ps1`    | Enables GuardDuty in a region using `New-GDDetector`; checks for existing detectors and supports S3 logs, Kubernetes audit logs, and malware protection                                      |
| `aws-ps-manage-kms-keys.ps1`     | Manages KMS keys with actions: Create (`New-KMSKey`), Describe, List, EnableRotation, DisableRotation, and CreateAlias                                                                       |

## Usage Examples

### Account Hardening

```powershell
.\aws-ps-account-hardening.ps1 `
    -HomeRegion eu-central-1 `
    -SecurityEmail security@example.com `
    -EnableCloudWatchAlarms
```

Run in dry-run mode to preview changes without applying them:

```powershell
.\aws-ps-account-hardening.ps1 -DryRun -EnableCloudWatchAlarms
```

### Account Unhardening

Remove specific security controls by specifying one or more switches:

```powershell
.\aws-ps-account-unhardening.ps1 `
    -Region us-east-1 `
    -AwsCliProfile default `
    -RemoveCloudTrail `
    -RemoveGuardDuty `
    -RemoveSecurityHub
```

Available removal switches: `-RemoveCloudTrail`, `-RemoveGuardDuty`,
`-RemoveSecurityHub`, `-RemoveConfigRecorder`,
`-RemoveS3BucketPolicies`, `-RemoveIAMPasswordPolicy`,
`-RemoveVPCFlowLogs`, `-RemoveSSMSettings`, `-RemoveAccountAlias`,
`-RemoveDefaultTags`.

## Notes

- `aws-ps-account-hardening.ps1` can target multiple regions in a
  single run via the `-TargetRegions` parameter.
- `aws-ps-account-unhardening.ps1` writes a log file
  (`aws-account-unhardening.log`) in the current directory.
- Use the unhardening script with caution in production; it is
  designed for lab and test teardown scenarios.
- A supplementary reference document (`README-aws-ps-account-hardening.md`)
  is included in this directory with additional hardening guidance.
