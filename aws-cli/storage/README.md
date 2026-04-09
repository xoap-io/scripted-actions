# AWS CLI - Storage Scripts

This directory contains PowerShell scripts for managing AWS storage services
(S3, EBS, EFS) using the AWS CLI.

## Prerequisites

- AWS CLI v2.16+ installed and configured
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`aws configure`)
- Appropriate IAM permissions for storage operations

## Available Scripts

### Amazon S3 (Simple Storage Service)

#### Bucket Management

- **aws-cli-create-s3-bucket.ps1** - Creates S3 buckets with optional
  configuration
- **aws-cli-delete-s3-bucket.ps1** - Deletes S3 buckets
- **aws-cli-list-s3-buckets.ps1** - Lists all S3 buckets in account
- **aws-cli-enable-s3-versioning.ps1** - Enables versioning on buckets
- **aws-cli-enable-s3-encryption.ps1** - Enables server-side encryption

#### Object Management

- **aws-cli-list-s3-objects.ps1** - Lists objects in a bucket
- **aws-cli-put-s3-object.ps1** - Uploads files to S3
- **aws-cli-get-s3-object.ps1** - Downloads files from S3
- **aws-cli-delete-s3-object.ps1** - Deletes objects from S3
- **aws-cli-copy-s3-object.ps1** - Copies objects within or between buckets
- **aws-cli-sync-s3.ps1** - Syncs directories with S3 buckets

### Amazon EBS (Elastic Block Store)

- **aws-cli-create-ebs-volume.ps1** - Creates EBS volumes
- **aws-cli-delete-ebs-volume.ps1** - Deletes EBS volumes
- **aws-cli-list-volumes.ps1** - Lists EBS volumes
- **aws-cli-attach-volume.ps1** - Attaches volumes to EC2 instances
- **aws-cli-detach-volume.ps1** - Detaches volumes from instances
- **aws-cli-modify-volume.ps1** - Modifies volume size, type, or IOPS
- **aws-cli-create-snapshot.ps1** - Creates EBS snapshots
- **aws-cli-list-snapshots.ps1** - Lists EBS snapshots
- **aws-cli-delete-snapshot.ps1** - Deletes snapshots

### Amazon EFS (Elastic File System)

- **aws-cli-create-efs.ps1** - Creates EFS file systems

### S3 Lifecycle and Replication

- **aws-cli-set-s3-lifecycle-policy.ps1** - Applies a lifecycle policy that
  transitions objects through Standard-IA and Glacier before expiration
- **aws-cli-enable-s3-replication.ps1** - Enables cross-region replication from
  a source bucket to a destination bucket; enables versioning automatically

### AWS Backup

- **aws-cli-create-backup-plan.ps1** - Creates an AWS Backup plan with a
  configurable schedule, retention period, and vault; outputs BackupPlanId
  and Arn
- **aws-cli-restore-from-backup.ps1** - Starts an AWS Backup restore job from a
  recovery point ARN; outputs RestoreJobId

## Usage Examples

### S3 Operations

#### Create an S3 Bucket

```powershell
.\aws-cli-create-s3-bucket.ps1 `
    -BucketName "my-app-bucket" `
    -Region us-east-1
```

#### Upload a File

```powershell
.\aws-cli-put-s3-object.ps1 `
    -BucketName "my-app-bucket" `
    -FilePath ".\document.pdf" `
    -Key "documents/document.pdf"
```

#### Sync Local Directory with S3

```powershell
.\aws-cli-sync-s3.ps1 `
    -LocalPath "C:\WebApp" `
    -S3Uri "s3://my-app-bucket/website/" `
    -Direction Upload
```

#### Enable Bucket Encryption

```powershell
.\aws-cli-enable-s3-encryption.ps1 `
    -BucketName "my-app-bucket" `
    -EncryptionType AES256
```

### EBS Operations

#### Create an EBS Volume

```powershell
.\aws-cli-create-ebs-volume.ps1 `
    -Size 100 `
    -VolumeType gp3 `
    -AvailabilityZone us-east-1a
```

#### Create a Snapshot

```powershell
.\aws-cli-create-snapshot.ps1 `
    -VolumeId vol-1234567890abcdef0 `
    -Description "Daily backup"
```

#### Attach Volume to Instance

```powershell
.\aws-cli-attach-volume.ps1 `
    -VolumeId vol-1234567890abcdef0 `
    -InstanceId i-1234567890abcdef0 `
    -Device /dev/sdf
```

## Storage Best Practices

### S3

- Enable versioning for critical data
- Use lifecycle policies for cost optimization
- Enable encryption at rest
- Implement bucket policies for access control
- Use S3 Intelligent-Tiering for varying access patterns
- Enable S3 Block Public Access by default

### EBS

- Regular snapshot schedules for backups
- Use appropriate volume types (gp3, io2, etc.) for workload
- Monitor volume performance metrics
- Enable EBS encryption for sensitive data
- Delete unused volumes and snapshots

### EFS

- Use appropriate performance mode (General Purpose vs. Max I/O)
- Enable encryption for compliance
- Implement lifecycle policies to move to IA storage class

## Error Handling

All scripts include:

- Bucket/volume name validation
- Resource existence checks
- Permission validation
- Comprehensive error messages
- Exit codes (0 = success, 1 = failure)

## Related Documentation

- [AWS S3 Documentation](https://docs.aws.amazon.com/s3/)
- [AWS EBS Documentation](https://docs.aws.amazon.com/ebs/)
- [AWS EFS Documentation](https://docs.aws.amazon.com/efs/)
- [AWS CLI Command Reference - S3](https://awscli.amazonaws.com/v2/documentation/api/latest/reference/s3/index.html)

## Support

For issues or questions, please refer to the main repository documentation.
