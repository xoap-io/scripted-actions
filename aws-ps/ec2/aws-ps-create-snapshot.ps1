<#
.SYNOPSIS
    Create a snapshot of an EBS volume.
.DESCRIPTION
    This script creates a snapshot of an EBS volume using AWS.Tools.EC2.
.PARAMETER VolumeId
    The ID of the EBS volume.
.PARAMETER Description
    (Optional) Description for the snapshot.
.EXAMPLE
    .\aws-ps-create-snapshot.ps1 -VolumeId vol-12345678 -Description "Backup before upgrade"
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId,
    [Parameter()]
    [string]$Description
)

$ErrorActionPreference = 'Stop'
try {
    $snap = New-EC2Snapshot -VolumeId $VolumeId -Description $Description
    Write-Host "Created snapshot: $($snap.SnapshotId) for volume $VolumeId." -ForegroundColor Green
} catch {
    Write-Error "Failed to create snapshot: $_"
    exit 1
}
