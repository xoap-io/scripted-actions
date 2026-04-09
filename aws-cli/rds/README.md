# AWS CLI - RDS Scripts

PowerShell scripts for managing Amazon Relational Database Service (RDS)
instances and snapshots using the AWS CLI.

## Prerequisites

- AWS CLI v2 installed and configured
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- AWS credentials configured (`aws configure` or environment variables)
- Appropriate IAM permissions for RDS operations (e.g. `AmazonRDSFullAccess`)

## Available Scripts

| Script                            | Description                                                                                  |
| --------------------------------- | -------------------------------------------------------------------------------------------- |
| `aws-cli-create-rds-instance.ps1` | Create a new Amazon RDS DB instance with configurable engine, class, storage, and networking |
| `aws-cli-create-rds-snapshot.ps1` | Create a manual snapshot of an existing RDS DB instance                                      |

## Usage Examples

### Create an RDS Instance (MySQL)

```powershell
.\aws-cli-create-rds-instance.ps1 `
    -DBInstanceIdentifier "my-db-01" `
    -DBInstanceClass "db.t3.micro" `
    -Engine "mysql" `
    -MasterUsername "admin" `
    -MasterUserPassword "MySecurePass123!" `
    -AllocatedStorage 20
```

### Create a Production PostgreSQL Instance with Multi-AZ

```powershell
.\aws-cli-create-rds-instance.ps1 `
    -DBInstanceIdentifier "prod-postgres-01" `
    -DBInstanceClass "db.m5.large" `
    -Engine "postgres" `
    -MasterUsername "dbadmin" `
    -MasterUserPassword "MySecurePass123!" `
    -DBName "appdb" `
    -AllocatedStorage 100 `
    -VpcSecurityGroupIds "sg-0a1b2c3d4e5f67890" `
    -DBSubnetGroupName "my-db-subnet-group" `
    -MultiAZ `
    -StorageEncrypted `
    -Region "us-east-1"
```

### Create a Manual Snapshot

```powershell
.\aws-cli-create-rds-snapshot.ps1 `
    -DBInstanceIdentifier "my-db-01" `
    -DBSnapshotIdentifier "my-db-01-snapshot-20260408"
```

### Create a Snapshot with Tags

```powershell
.\aws-cli-create-rds-snapshot.ps1 `
    -DBInstanceIdentifier "prod-postgres-01" `
    -DBSnapshotIdentifier "prod-postgres-backup-20260408" `
    -Region "us-east-1" `
    -Tags '[{"Key":"Environment","Value":"prod"},{"Key":"Purpose","Value":"manual-backup"}]'
```

## Related Documentation

- [Amazon RDS Documentation](https://docs.aws.amazon.com/rds/)
- [AWS CLI RDS Reference](https://docs.aws.amazon.com/cli/latest/reference/rds/)
- [create-db-instance](https://docs.aws.amazon.com/cli/latest/reference/rds/create-db-instance.html)
- [create-db-snapshot](https://docs.aws.amazon.com/cli/latest/reference/rds/create-db-snapshot.html)
