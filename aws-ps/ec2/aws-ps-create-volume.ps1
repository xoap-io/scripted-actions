<#
.SYNOPSIS
    Create a new EBS volume.
.DESCRIPTION
    This script creates a new EBS volume using AWS.Tools.EC2.
.PARAMETER AvailabilityZone
    The availability zone for the volume.
.PARAMETER Size
    The size of the volume in GiB.
.EXAMPLE
    .\aws-ps-create-volume.ps1 -AvailabilityZone us-east-1a -Size 20
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9-]+$')]
    [string]$AvailabilityZone,
    [Parameter(Mandatory)]
    [ValidateRange(1, 16384)]
    [int]$Size
)

$ErrorActionPreference = 'Stop'
try {
    $vol = New-EC2Volume -AvailabilityZone $AvailabilityZone -Size $Size
    Write-Host "Created EBS volume: $($vol.VolumeId) ($Size GiB in $AvailabilityZone)" -ForegroundColor Green
} catch {
    Write-Error "Failed to create EBS volume: $_"
    exit 1
}
