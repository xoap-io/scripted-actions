<#
.SYNOPSIS
    Delete an EBS volume.
.DESCRIPTION
    This script deletes an EBS volume using AWS.Tools.EC2.
.PARAMETER VolumeId
    The ID of the EBS volume to delete.
.EXAMPLE
    .\aws-ps-delete-volume.ps1 -VolumeId vol-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId
)

$ErrorActionPreference = 'Stop'
try {
    Remove-EC2Volume -VolumeId $VolumeId -Force
    Write-Host "Deleted EBS volume $VolumeId." -ForegroundColor Green
} catch {
    Write-Error "Failed to delete volume: $_"
    exit 1
}
