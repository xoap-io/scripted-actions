# Security Scripts

PowerShell scripts for managing AWS EC2 security groups and network
ACLs using the AWS CLI. Covers ingress and egress rule management,
security group lifecycle, and network ACL entry management.

## Prerequisites

- AWS CLI v2
- Appropriate AWS credentials configured

## Available Scripts

| Script                                        | Description                                                                      |
| --------------------------------------------- | -------------------------------------------------------------------------------- |
| `aws-cli-authorize-ec2-security-group.ps1`    | Adds an ingress rule to a security group                                         |
| `aws-cli-authorize-security-group-egress.ps1` | Adds an egress rule to a security group                                          |
| `aws-cli-create-iam-policy.ps1`               | Creates a managed IAM policy and optionally attaches it to a role or user        |
| `aws-cli-create-iam-role.ps1`                 | Creates an IAM role with a trust policy document                                 |
| `aws-cli-create-kms-key.ps1`                  | Creates a KMS key with optional alias and automatic rotation                     |
| `aws-cli-create-network-acl-entry.ps1`        | Creates an entry (rule) in a network ACL                                         |
| `aws-cli-create-network-acl.ps1`              | Creates a network ACL for a specified VPC                                        |
| `aws-cli-delete-ec2-security-group.ps1`       | Deletes a security group                                                         |
| `aws-cli-delete-network-acl-entry.ps1`        | Deletes an entry from a network ACL                                              |
| `aws-cli-delete-network-acl.ps1`              | Deletes a network ACL                                                            |
| `aws-cli-describe-network-acls.ps1`           | Lists and describes network ACLs                                                 |
| `aws-cli-describe-security-groups.ps1`        | Lists and describes security groups                                              |
| `aws-cli-enable-guardduty.ps1`                | Enables AWS GuardDuty in a region with optional S3, EKS, and malware protections |
| `aws-cli-revoke-security-group-egress.ps1`    | Removes an egress rule from a security group                                     |
| `aws-cli-revoke-security-group-ingress.ps1`   | Removes an ingress rule from a security group                                    |
| `aws-cli-rotate-secrets-manager-secret.ps1`   | Rotates an AWS Secrets Manager secret and configures a rotation schedule         |
| `wip_aws-cli-create-ec2-security-group.ps1`   | Creates a security group and adds an initial ingress rule (work in progress)     |

## Usage Examples

### Authorize an Ingress Rule

```powershell
.\aws-cli-authorize-ec2-security-group.ps1 `
    -AwsSecurityGroupId "sg-0a1b2c3d4e5f67890" `
    -AwsSecurityGroupProtocol "tcp" `
    -AwsSecurityGroupPort "443" `
    -AwsSecurityGroupCidr "0.0.0.0/0"
```

### Authorize an Egress Rule

```powershell
.\aws-cli-authorize-security-group-egress.ps1 `
    -GroupId "sg-0a1b2c3d4e5f67890" `
    -Protocol "tcp" `
    -Port "443" `
    -Cidr "0.0.0.0/0"
```

### Create a Network ACL

```powershell
.\aws-cli-create-network-acl.ps1 -VpcId "vpc-0a1b2c3d4e5f67890"
```

### Add a Network ACL Entry

```powershell
.\aws-cli-create-network-acl-entry.ps1 `
    -NetworkAclId "acl-0a1b2c3d4e5f67890" `
    -RuleNumber 100 `
    -Protocol "tcp" `
    -RuleAction "allow" `
    -Egress $false `
    -CidrBlock "10.0.0.0/16"
```

### Revoke an Ingress Rule

```powershell
.\aws-cli-revoke-security-group-ingress.ps1 `
    -GroupId "sg-0a1b2c3d4e5f67890" `
    -Protocol "tcp" `
    -Port "22" `
    -Cidr "0.0.0.0/0"
```

### Create a Security Group with an Ingress Rule

```powershell
.\wip_aws-cli-create-ec2-security-group.ps1 `
    -AwsSecurityGroupName "web-servers" `
    -AwsSecurityGroupDescription "HTTP and HTTPS access" `
    -AwsVpcId "vpc-0a1b2c3d4e5f67890" `
    -Protocol "tcp" `
    -Port "443" `
    -Cidr "0.0.0.0/0"
```

### Create an IAM Role

```powershell
.\aws-cli-create-iam-role.ps1 `
    -RoleName "MyLambdaRole" `
    -TrustPolicy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
        "Principal":{"Service":"lambda.amazonaws.com"},
        "Action":"sts:AssumeRole"}]}' `
    -Description "Execution role for Lambda functions" `
    -Tags "Env=prod,Team=platform"
```

### Create an IAM Policy

```powershell
.\aws-cli-create-iam-policy.ps1 `
    -PolicyName "MyS3ReadPolicy" `
    -PolicyDocument '{"Version":"2012-10-17","Statement":[{"Effect":"Allow",
        "Action":["s3:GetObject","s3:ListBucket"],"Resource":"*"}]}' `
    -AttachToRole "MyLambdaRole"
```

### Create a KMS Key

```powershell
.\aws-cli-create-kms-key.ps1 `
    -Region "us-east-1" `
    -Description "Encryption key for application secrets" `
    -Alias "alias/app-secrets" `
    -EnableRotation
```

### Enable GuardDuty

```powershell
.\aws-cli-enable-guardduty.ps1 `
    -Region "us-east-1" `
    -FindingPublishingFrequency "ONE_HOUR" `
    -EnableS3Protection `
    -EnableEksProtection
```

### Rotate a Secrets Manager Secret

```powershell
.\aws-cli-rotate-secrets-manager-secret.ps1 `
    -Region "us-east-1" `
    -SecretId "prod/myapp/dbpassword" `
    -RotationDays 30 `
    -RotateImmediately
```

## Notes

- The `wip_` prefix on `wip_aws-cli-create-ec2-security-group.ps1`
  indicates it is a work in progress and may not be production-ready.
- Network ACL rules are evaluated in order from lowest to highest
  rule number; the first matching rule is applied.
- Security groups are stateful; network ACLs are stateless and require
  explicit rules for both inbound and outbound traffic.
