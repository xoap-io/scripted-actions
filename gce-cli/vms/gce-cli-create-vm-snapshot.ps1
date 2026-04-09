<#
.SYNOPSIS
    Create a snapshot of a GCE VM persistent disk using the gcloud CLI.

.DESCRIPTION
    This script creates a snapshot of a Google Compute Engine persistent disk
    using `gcloud compute disks snapshot`. It automatically discovers disks
    attached to the specified VM instance. If DiskName is omitted the boot
    disk is snapshotted. If SnapshotName is omitted an auto-generated name is
    used. If ProjectId is omitted it is resolved from the active gcloud config.

.PARAMETER ProjectId
    The Google Cloud project ID. If omitted, the value from
    `gcloud config get-value project` is used.

.PARAMETER Zone
    The zone where the VM instance and disk are located.
    Examples: us-central1-a, europe-west1-b, asia-east1-c

.PARAMETER InstanceName
    The name of the VM instance whose disk will be snapshotted.

.PARAMETER DiskName
    The name of the disk to snapshot. If omitted, the boot disk of the
    instance is used.

.PARAMETER SnapshotName
    The name for the new snapshot. If omitted, a name is auto-generated
    using the pattern: <instance>-snap-<timestamp>.

.PARAMETER Description
    An optional human-readable description for the snapshot.

.PARAMETER StorageLocation
    The Cloud Storage multi-region or region where the snapshot will be
    stored. Examples: us, eu, asia, us-central1.

.EXAMPLE
    .\gce-cli-create-vm-snapshot.ps1 `
      -Zone "us-central1-a" `
      -InstanceName "web-server-01"

    Snapshot the boot disk of the VM using auto-generated snapshot name.

.EXAMPLE
    .\gce-cli-create-vm-snapshot.ps1 `
      -ProjectId "my-project-123" `
      -Zone "us-central1-a" `
      -InstanceName "web-server-01" `
      -DiskName "data-disk-01" `
      -SnapshotName "data-backup-20260408" `
      -Description "Pre-maintenance backup" `
      -StorageLocation "eu"

    Snapshot a named data disk with a custom snapshot name stored in the EU.

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
    https://cloud.google.com/sdk/gcloud/reference/compute/disks/snapshot

.COMPONENT
    Google Cloud CLI Compute Engine
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The Google Cloud project ID. Defaults to the active gcloud config project.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{4,28}[a-z0-9]$')]
    [string]$ProjectId,

    [Parameter(Mandatory = $true, HelpMessage = "The zone where the VM instance and disk are located. Example: us-central1-a.")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]
    [string]$Zone,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the VM instance whose disk will be snapshotted.")]
    [ValidateNotNullOrEmpty()]
    [string]$InstanceName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the disk to snapshot. Defaults to the boot disk.")]
    [string]$DiskName,

    [Parameter(Mandatory = $false, HelpMessage = "The name for the new snapshot. Auto-generated if omitted.")]
    [ValidatePattern('^[a-z][a-z0-9\-]{0,61}[a-z0-9]$')]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false, HelpMessage = "An optional human-readable description for the snapshot.")]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Cloud Storage location for the snapshot. Examples: us, eu, asia, us-central1.")]
    [string]$StorageLocation
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting disk snapshot operation..." -ForegroundColor Green

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

    # Discover the disk to snapshot
    if (-not $DiskName) {
        Write-Host "🔍 Discovering boot disk for instance '$InstanceName'..." -ForegroundColor Cyan
        $describeResult = & gcloud compute instances describe $InstanceName `
            --project $ProjectId `
            --zone $Zone `
            --format "json(disks)" 2>&1

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to describe instance '$InstanceName'. $($describeResult -join ' ')"
        }

        $diskInfo = $describeResult | ConvertFrom-Json
        $bootDisk = $diskInfo.disks | Where-Object { $_.boot -eq $true } | Select-Object -First 1

        if (-not $bootDisk) {
            throw "Could not find a boot disk attached to instance '$InstanceName'."
        }

        $DiskName = $bootDisk.source.Split('/')[-1]
        Write-Host "ℹ️  Using boot disk: $DiskName" -ForegroundColor Yellow
    }

    # Auto-generate snapshot name if not provided
    if (-not $SnapshotName) {
        $timestamp = (Get-Date -Format 'yyyyMMddHHmmss')
        $SnapshotName = "$InstanceName-snap-$timestamp"
        # Ensure name is lowercase and within length limit
        $SnapshotName = $SnapshotName.ToLower() -replace '[^a-z0-9\-]', '-'
        if ($SnapshotName.Length -gt 63) {
            $SnapshotName = $SnapshotName.Substring(0, 63)
        }
        Write-Host "ℹ️  Auto-generated snapshot name: $SnapshotName" -ForegroundColor Yellow
    }

    Write-Host "🔧 Creating snapshot '$SnapshotName' from disk '$DiskName'..." -ForegroundColor Cyan

    $arguments = @(
        'compute', 'disks', 'snapshot', $DiskName,
        '--project', $ProjectId,
        '--zone', $Zone,
        '--snapshot-names', $SnapshotName
    )

    if ($Description) {
        $arguments += '--description', $Description
    }

    if ($StorageLocation) {
        $arguments += '--storage-location', $StorageLocation
    }

    $result = & gcloud @arguments 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Snapshot '$SnapshotName' created successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Project      : $ProjectId" -ForegroundColor Green
        Write-Host "   Zone         : $Zone" -ForegroundColor Green
        Write-Host "   Instance     : $InstanceName" -ForegroundColor Green
        Write-Host "   Source Disk  : $DiskName" -ForegroundColor Green
        Write-Host "   Snapshot Name: $SnapshotName" -ForegroundColor Green
        if ($StorageLocation) {
            Write-Host "   Storage Loc  : $StorageLocation" -ForegroundColor Green
        }
        Write-Host "💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   List snapshots: gcloud compute snapshots list --project $ProjectId" -ForegroundColor Yellow
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
