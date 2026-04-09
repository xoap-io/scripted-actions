# Google Cloud CLI - Storage Scripts

PowerShell scripts for managing Google Cloud Storage buckets and persistent
disks using the gcloud CLI.

## Prerequisites

- Google Cloud SDK installed (includes gcloud CLI)
- PowerShell 5.1 or later
- Active Google Cloud project with appropriate APIs enabled
- Authenticated gcloud session (`gcloud auth login`)
- Default project set (`gcloud config set project PROJECT_ID`)

## Available Scripts

| Script                      | Description                                                              |
| --------------------------- | ------------------------------------------------------------------------ |
| `gce-cli-create-bucket.ps1` | Create a Cloud Storage bucket with configurable location and class       |
| `gce-cli-upload-object.ps1` | Upload a local file or folder to a Cloud Storage bucket                  |
| `gce-cli-create-disk.ps1`   | Create a Compute Engine persistent disk (blank, from image, or snapshot) |

## Usage Examples

### Create a Cloud Storage Bucket

```powershell
.\gce-cli-create-bucket.ps1 `
  -BucketName "my-app-assets-20260408" `
  -Location "EU"
```

Create a Coldline bucket with versioning and uniform access:

```powershell
.\gce-cli-create-bucket.ps1 `
  -ProjectId "my-project-123" `
  -BucketName "archive-data-2026" `
  -Location "us-central1" `
  -StorageClass COLDLINE `
  -EnableVersioning `
  -EnableUniformAccess `
  -Description "Long-term archive storage"
```

### Upload an Object to a Bucket

```powershell
.\gce-cli-upload-object.ps1 `
  -LocalPath "C:\reports\report.csv" `
  -BucketName "my-app-assets-20260408"
```

Recursively upload a folder to a prefixed path:

```powershell
.\gce-cli-upload-object.ps1 `
  -ProjectId "my-project-123" `
  -LocalPath "C:\data\exports" `
  -BucketName "archive-data-2026" `
  -ObjectPrefix "exports/2026/04/" `
  -Recursive
```

### Create a Persistent Disk

```powershell
.\gce-cli-create-disk.ps1 `
  -Zone "us-central1-a" `
  -DiskName "data-disk-01" `
  -SizeGb 100
```

Create a disk restored from a snapshot:

```powershell
.\gce-cli-create-disk.ps1 `
  -ProjectId "my-project-123" `
  -Zone "europe-west1-b" `
  -DiskName "restore-disk-01" `
  -DiskType pd-ssd `
  -SizeGb 200 `
  -SourceSnapshot "web-server-snap-20260408" `
  -Description "Restored from pre-maintenance snapshot"
```
