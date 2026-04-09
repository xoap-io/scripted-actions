# Google Cloud CLI - Cloud SQL Scripts

PowerShell scripts for managing Google Cloud SQL instances using the gcloud CLI.

## Prerequisites

- Google Cloud SDK installed (includes gcloud CLI)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Active Google Cloud project with Cloud SQL Admin API enabled
- Authenticated gcloud session (`gcloud auth login`)
- Appropriate IAM permissions (Cloud SQL Admin role)

## Available Scripts

| Script                         | Description                                                                                                                       |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `gce-cli-create-cloud-sql.ps1` | Create a new Cloud SQL instance (MySQL, PostgreSQL, or SQL Server) with configurable tier, region, storage, and high availability |

## Usage Examples

### Create a MySQL 8.0 Instance

```powershell
.\gce-cli-create-cloud-sql.ps1 `
  -InstanceName "my-mysql-instance" `
  -DatabaseVersion "MYSQL_8_0" `
  -RootPassword "MySecureRootPass123!"
```

### Create a Production PostgreSQL Instance with High Availability

```powershell
.\gce-cli-create-cloud-sql.ps1 `
  -InstanceName "prod-postgres-01" `
  -DatabaseVersion "POSTGRES_15" `
  -Tier "db-n1-standard-2" `
  -Region "europe-west1" `
  -ProjectId "my-project-123" `
  -StorageSize 50 `
  -StorageAutoIncrease `
  -HighAvailability
```

## Related Documentation

- [Cloud SQL Documentation](https://cloud.google.com/sql/docs)
- [gcloud sql instances create](https://cloud.google.com/sdk/gcloud/reference/sql/instances/create)
- [Cloud SQL Pricing](https://cloud.google.com/sql/pricing)
