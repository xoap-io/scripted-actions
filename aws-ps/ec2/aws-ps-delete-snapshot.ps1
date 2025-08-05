<#
.SYNOPSIS
    Delete a snapshot.
.DESCRIPTION
    This script deletes a snapshot using AWS.Tools.EC2.
.PARAMETER SnapshotId
    The ID of the snapshot to delete.
.EXAMPLE
    .\aws-ps-delete-snapshot.ps1 -SnapshotId snap-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^snap-[a-zA-Z0-9]{8,}$')]
    [string]$SnapshotId
)

$ErrorActionPreference = 'Stop'
try {
    Remove-EC2Snapshot -SnapshotId $SnapshotId -Force
    Write-Host "Deleted snapshot $SnapshotId." -ForegroundColor Green
} catch {
    Write-Error "Failed to delete snapshot: $_"
    exit 1
}
