<#
.SYNOPSIS
    Upload a local file or folder to a Google Cloud Storage bucket using gcloud.

.DESCRIPTION
    This script uploads a local file or directory to a Cloud Storage bucket
    using `gcloud storage cp`. For directory uploads, use the -Recursive switch.
    An optional ObjectPrefix can be used to set the destination path within the
    bucket. If ProjectId is omitted it is resolved from the active gcloud config.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER LocalPath
    The local file or folder path to upload.

.PARAMETER BucketName
    The destination Cloud Storage bucket name (without gs:// prefix).

.PARAMETER ObjectPrefix
    Optional destination path prefix inside the bucket.
    Example: "backups/2026/" will upload to gs://bucket/backups/2026/

.PARAMETER Recursive
    Upload a directory recursively. Required when LocalPath is a folder.

.PARAMETER ContentType
    Optional MIME content type for the uploaded object.
    Example: "application/json" or "image/png".

.EXAMPLE
    .\gce-cli-upload-object.ps1 `
      -LocalPath "C:\reports\report.csv" `
      -BucketName "my-app-assets-20260408"

    Upload a single file to the root of the bucket.

.EXAMPLE
    .\gce-cli-upload-object.ps1 `
      -ProjectId "my-project-123" `
      -LocalPath "C:\data\exports" `
      -BucketName "archive-data-2026" `
      -ObjectPrefix "exports/2026/04/" `
      -Recursive

    Recursively upload a folder to a prefixed path in the bucket.

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
    https://cloud.google.com/sdk/gcloud/reference/storage/cp

.COMPONENT
    Google Cloud CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The local file or folder path to upload.")]
    [ValidateNotNullOrEmpty()]
    [string]$LocalPath,

    [Parameter(Mandatory = $true, HelpMessage = "The destination Cloud Storage bucket name (without gs:// prefix).")]
    [ValidateNotNullOrEmpty()]
    [string]$BucketName,

    [Parameter(Mandatory = $false, HelpMessage = "Optional destination path prefix inside the bucket. Example: 'backups/2026/'.")]
    [string]$ObjectPrefix,

    [Parameter(Mandatory = $false, HelpMessage = "Upload a directory recursively. Required when LocalPath is a folder.")]
    [switch]$Recursive,

    [Parameter(Mandatory = $false, HelpMessage = "Optional MIME content type for the uploaded object. Example: 'application/json'.")]
    [string]$ContentType
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting Cloud Storage upload..." -ForegroundColor Green

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

    # Validate local path exists
    if (-not (Test-Path -Path $LocalPath)) {
        throw "LocalPath '$LocalPath' does not exist."
    }

    $isDirectory = (Get-Item $LocalPath).PSIsContainer

    if ($isDirectory -and -not $Recursive) {
        throw "LocalPath '$LocalPath' is a directory. Use the -Recursive switch to upload directories."
    }

    # Build destination URI
    $bucketBase = $BucketName -replace '^gs://', ''
    if ($ObjectPrefix) {
        $prefix = $ObjectPrefix.TrimStart('/')
        $destination = "gs://$bucketBase/$prefix"
    }
    else {
        $destination = "gs://$bucketBase/"
    }

    Write-Host "🔧 Uploading '$LocalPath' to '$destination'..." -ForegroundColor Cyan

    $arguments = @(
        'storage', 'cp',
        '--project', $ProjectId
    )

    if ($Recursive) {
        $arguments += '--recursive'
    }

    if ($ContentType) {
        $arguments += '--content-type', $ContentType
    }

    $arguments += $LocalPath, $destination

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Upload completed successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Project    : $ProjectId" -ForegroundColor Green
        Write-Host "   Source     : $LocalPath" -ForegroundColor Green
        Write-Host "   Destination: $destination" -ForegroundColor Green
        if ($ContentType) {
            Write-Host "   ContentType: $ContentType" -ForegroundColor Green
        }
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
