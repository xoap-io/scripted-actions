<#
.SYNOPSIS
    Attach an EBS volume to an EC2 instance.
.DESCRIPTION
    This script attaches an EBS volume to an EC2 instance using AWS.Tools.EC2.
.PARAMETER InstanceId
    The ID of the EC2 instance.
.PARAMETER VolumeId
    The ID of the EBS volume.
.PARAMETER Device
    The device name (e.g., /dev/xvdf).
.EXAMPLE
    .\aws-ps-attach-volume.ps1 -InstanceId i-12345678 -VolumeId vol-12345678 -Device /dev/xvdf
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,
    [Parameter(Mandatory)]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId,
    [Parameter(Mandatory)]
    [ValidatePattern('^/dev/[a-zA-Z0-9]+$')]
    [string]$Device
)

$ErrorActionPreference = 'Stop'
try {
    Register-EC2Volume -InstanceId $InstanceId -VolumeId $VolumeId -Device $Device
    Write-Host "Attached volume $VolumeId to instance $InstanceId as $Device." -ForegroundColor Green
} catch {
    Write-Error "Failed to attach volume: $_"
    exit 1
}
