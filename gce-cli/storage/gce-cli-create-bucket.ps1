<#
.SYNOPSIS
    Create a Google Cloud Storage bucket using the gcloud CLI.

.DESCRIPTION
    This script creates a Google Cloud Storage bucket using
    `gcloud storage buckets create`. Supports configuring the storage
    location, storage class, uniform bucket-level access, and object
    versioning. The gs:// prefix is added automatically if not supplied.
    If ProjectId is omitted it is resolved from the active gcloud config.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER BucketName
    The name of the bucket to create. Do not include the gs:// prefix;
    the script adds it automatically. Bucket names must be globally unique.

.PARAMETER Location
    The location where the bucket will be created.
    Examples: US, EU, ASIA, us-central1, europe-west1

.PARAMETER StorageClass
    The storage class for the bucket. Defaults to STANDARD.
    Valid values: STANDARD, NEARLINE, COLDLINE, ARCHIVE.

.PARAMETER EnableVersioning
    Enable object versioning to retain older versions of objects.

.PARAMETER EnableUniformAccess
    Enable uniform bucket-level access (disables per-object ACLs).
    Recommended for new buckets.

.PARAMETER Description
    An optional human-readable description (label) for the bucket.

.EXAMPLE
    .\gce-cli-create-bucket.ps1 `
      -BucketName "my-app-assets-20260408" `
      -Location "EU"

    Create a bucket in the EU multi-region with default settings.

.EXAMPLE
    .\gce-cli-create-bucket.ps1 `
      -ProjectId "my-project-123" `
      -BucketName "archive-data-2026" `
      -Location "us-central1" `
      -StorageClass COLDLINE `
      -EnableVersioning `
      -EnableUniformAccess `
      -Description "Long-term archive storage"

    Create a Coldline bucket with versioning and uniform access enabled.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Google Cloud CLI (gcloud) - https://cloud.google.com/sdk/docs/install

.LINK
    https://cloud.google.com/sdk/gcloud/reference/storage/buckets/create

.COMPONENT
    Google Cloud CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The bucket name (without gs:// prefix). Must be globally unique.")]
    [ValidateNotNullOrEmpty()]
    [string]$BucketName,

    [Parameter(Mandatory = $true, HelpMessage = "Storage location. Examples: US, EU, ASIA, us-central1, europe-west1.")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Storage class: STANDARD, NEARLINE, COLDLINE, or ARCHIVE. Defaults to STANDARD.")]
    [ValidateSet('STANDARD', 'NEARLINE', 'COLDLINE', 'ARCHIVE')]
    [string]$StorageClass = 'STANDARD',

    [Parameter(Mandatory = $false, HelpMessage = "Enable object versioning to retain older object versions.")]
    [switch]$EnableVersioning,

    [Parameter(Mandatory = $false, HelpMessage = "Enable uniform bucket-level access (disables per-object ACLs).")]
    [switch]$EnableUniformAccess,

    [Parameter(Mandatory = $false, HelpMessage = "An optional human-readable description for the bucket.")]
    [string]$Description
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting Cloud Storage bucket creation..." -ForegroundColor Green

    # Resolve ProjectId from gcloud config if not provided
    if (-not $ProjectId) {
        Write-Host "🔍 Resolving project from gcloud config..." -ForegroundColor Cyan
        $ProjectId = & gcloud config get-value project 2>$null
        if (-not $ProjectId) {
            throw "No project specified and no default project found in gcloud config. " +
                  "Set a default with: gcloud config set project PROJECT_ID"
        }
        Write-Host "ℹ️  Using project: $ProjectId" -ForegroundColor Yellow
    }

    # Ensure bucket URI has the gs:// prefix
    if ($BucketName -notlike 'gs://*') {
        $BucketUri = "gs://$BucketName"
    }
    else {
        $BucketUri = $BucketName
    }

    Write-Host "🔧 Creating bucket '$BucketUri' in location '$Location'..." -ForegroundColor Cyan

    $arguments = @(
        'storage', 'buckets', 'create', $BucketUri,
        '--project', $ProjectId,
        '--location', $Location,
        '--default-storage-class', $StorageClass
    )

    if ($EnableUniformAccess) {
        $arguments += '--uniform-bucket-level-access'
    }

    if ($EnableVersioning) {
        $arguments += '--versioning'
    }

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        # Apply description label if provided
        if ($Description) {
            $labelKey = 'description'
            $labelValue = $Description.ToLower() -replace '[^a-z0-9_\-]', '-'
            & gcloud storage buckets update $BucketUri `
                --update-labels="${labelKey}=${labelValue}" 2>$null | Out-Null
        }

        Write-Host "✅ Bucket '$BucketUri' created successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Project        : $ProjectId" -ForegroundColor Green
        Write-Host "   Bucket         : $BucketUri" -ForegroundColor Green
        Write-Host "   Location       : $Location" -ForegroundColor Green
        Write-Host "   Storage Class  : $StorageClass" -ForegroundColor Green
        Write-Host "   Versioning     : $($EnableVersioning.IsPresent)" -ForegroundColor Green
        Write-Host "   Uniform Access : $($EnableUniformAccess.IsPresent)" -ForegroundColor Green
        Write-Host "💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   Upload files: .\gce-cli-upload-object.ps1 -BucketName $BucketName" -ForegroundColor Yellow
    }
    else {
        $errorMessage = $result -join "`n"
        throw "gcloud exited with code $LASTEXITCODE. $errorMessage"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
