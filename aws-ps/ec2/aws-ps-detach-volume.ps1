<#
.SYNOPSIS
    Detach an EBS volume from an EC2 instance.
.DESCRIPTION
    This script detaches an EBS volume from an EC2 instance using AWS.Tools.EC2.
.PARAMETER VolumeId
    The ID of the EBS volume.
.EXAMPLE
    .\aws-ps-detach-volume.ps1 -VolumeId vol-12345678
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
    Unregister-EC2Volume -VolumeId $VolumeId
    Write-Host "Detached volume $VolumeId." -ForegroundColor Green
} catch {
    Write-Error "Failed to detach volume: $_"
    exit 1
}
