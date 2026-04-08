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

| Script | Description |
| --- | --- |
| `aws-ps-account-hardening.ps1` | Applies CIS AWS Foundations v3.0.0-aligned hardening: CloudTrail, GuardDuty, Security Hub, AWS Config, IAM password policy, VPC Flow Logs, EBS encryption, CloudWatch alarms, and SNS alerts |
| `aws-ps-account-unhardening.ps1` | Reverts hardening actions selectively via switches; intended for lab or teardown scenarios |

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
