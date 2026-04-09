<#
.SYNOPSIS
    Create a Google Cloud persistent disk using the gcloud CLI.

.DESCRIPTION
    This script creates a Google Compute Engine persistent disk using
    `gcloud compute disks create`. Supports blank disks and disks created
    from an existing image or snapshot. If ProjectId is omitted it is
    resolved from the active gcloud configuration.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER Zone
    The zone in which to create the disk.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER DiskName
    The name for the new persistent disk.

.PARAMETER DiskType
    The disk type. Defaults to pd-balanced.
    Valid values: pd-standard, pd-ssd, pd-balanced, pd-extreme.

.PARAMETER SizeGb
    The size of the disk in GB. Valid range: 1-65536.

.PARAMETER SourceImage
    Optional source image for the disk contents.
    Example: "projects/debian-cloud/global/images/family/debian-11"

.PARAMETER SourceSnapshot
    Optional source snapshot for the disk contents.
    Example: "my-snapshot-name"

.PARAMETER Description
    An optional human-readable description for the disk.

.EXAMPLE
    .\gce-cli-create-disk.ps1 `
      -Zone "us-central1-a" `
      -DiskName "data-disk-01" `
      -SizeGb 100

    Create a blank 100 GB pd-balanced disk in the active config project.

.EXAMPLE
    .\gce-cli-create-disk.ps1 `
      -ProjectId "my-project-123" `
      -Zone "europe-west1-b" `
      -DiskName "restore-disk-01" `
      -DiskType pd-ssd `
      -SizeGb 200 `
      -SourceSnapshot "web-server-snap-20260408" `
      -Description "Restored from pre-maintenance snapshot"

    Create a 200 GB SSD disk restored from a snapshot.

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
    https://cloud.google.com/sdk/gcloud/reference/compute/disks/create

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The zone in which to create the disk. Example: us-central1-a.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new persistent disk.")]
    [ValidateNotNullOrEmpty()]
    [string]$DiskName,

    [Parameter(Mandatory = $false, HelpMessage = "The disk type: pd-standard, pd-ssd, pd-balanced, pd-extreme. Defaults to pd-balanced.")]
    [ValidateSet('pd-standard', 'pd-ssd', 'pd-balanced', 'pd-extreme')]
    [string]$DiskType = 'pd-balanced',

    [Parameter(Mandatory = $true, HelpMessage = "The size of the disk in GB. Valid range: 1-65536.")]
    [ValidateRange(1, 65536)]
    [int]$SizeGb,

    [Parameter(Mandatory = $false, HelpMessage = "Source image for the disk. Example: 'projects/debian-cloud/global/images/family/debian-11'.")]
    [string]$SourceImage,

    [Parameter(Mandatory = $false, HelpMessage = "Source snapshot name for the disk contents.")]
    [string]$SourceSnapshot,

    [Parameter(Mandatory = $false, HelpMessage = "An optional human-readable description for the disk.")]
    [string]$Description
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting persistent disk creation..." -ForegroundColor Green

    # Validate that SourceImage and SourceSnapshot are not both specified
    if ($SourceImage -and $SourceSnapshot) {
        throw "Specify either -SourceImage or -SourceSnapshot, not both."
    }

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

    $diskSource = if ($SourceImage) { "image: $SourceImage" }
                  elseif ($SourceSnapshot) { "snapshot: $SourceSnapshot" }
                  else { "blank" }

    Write-Host "🔧 Creating $DiskType disk '$DiskName' (${SizeGb} GB, source: $diskSource) in zone '$Zone'..." -ForegroundColor Cyan

    $arguments = @(
        'compute', 'disks', 'create', $DiskName,
        '--project', $ProjectId,
        '--zone', $Zone,
        '--type', $DiskType,
        '--size', "${SizeGb}GB"
    )

    if ($SourceImage) {
        $arguments += '--image', $SourceImage
    }
    elseif ($SourceSnapshot) {
        $arguments += '--source-snapshot', $SourceSnapshot
    }

    if ($Description) {
        $arguments += '--description', $Description
    }

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Persistent disk '$DiskName' created successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Project  : $ProjectId" -ForegroundColor Green
        Write-Host "   Zone     : $Zone" -ForegroundColor Green
        Write-Host "   Disk     : $DiskName" -ForegroundColor Green
        Write-Host "   Type     : $DiskType" -ForegroundColor Green
        Write-Host "   Size     : ${SizeGb} GB" -ForegroundColor Green
        Write-Host "   Source   : $diskSource" -ForegroundColor Green
        Write-Host "💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   Attach to VM: gcloud compute instances attach-disk INSTANCE --disk $DiskName --zone $Zone" -ForegroundColor Yellow
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
