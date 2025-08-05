<#
.SYNOPSIS
    Create an AMI from a configured NICE DCV Windows instance.
.DESCRIPTION
    This script creates an AMI from a Windows EC2 instance with NICE DCV installed.
.PARAMETER InstanceId
    The EC2 instance ID.
.PARAMETER AmiName
    The name for the new AMI.
.EXAMPLE
    .\nice-dcv-create-ami-windows.ps1 -InstanceId i-12345678 -AmiName "DCV-Windows-2025"
.LINK
    https://docs.aws.amazon.com/dcv/latest/userguide/setting-up-installing-windows.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,128}$')]
    [string]$AmiName
)

$ErrorActionPreference = 'Stop'
try {
    $ami = New-EC2Image -InstanceId $InstanceId -Name $AmiName
    Write-Host "AMI creation initiated: $($ami.ImageId) from instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to create AMI: $_"
    exit 1
}
