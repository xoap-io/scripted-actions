<#
.SYNOPSIS
    Attach an EBS volume to an EC2 instance.

.DESCRIPTION
    This script attaches an EBS volume to an EC2 instance using the Register-EC2Volume cmdlet from AWS.Tools.EC2.

.PARAMETER InstanceId
    The ID of the EC2 instance to attach the volume to.

.PARAMETER VolumeId
    The ID of the EBS volume to attach.

.PARAMETER Device
    The device name to use for the volume attachment (e.g., /dev/xvdf).

.EXAMPLE
    .\aws-ps-attach-volume.ps1 -InstanceId i-12345678 -VolumeId vol-12345678 -Device /dev/xvdf

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.EC2

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EC2 instance (e.g. i-12345678abcdef01).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EBS volume (e.g. vol-12345678abcdef01).")]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId,

    [Parameter(Mandatory = $true, HelpMessage = "The device name for the volume attachment (e.g. /dev/xvdf).")]
    [ValidatePattern('^/dev/[a-zA-Z0-9]+$')]
    [string]$Device
)

$ErrorActionPreference = 'Stop'

try {
    Register-EC2Volume -InstanceId $InstanceId -VolumeId $VolumeId -Device $Device
    Write-Host "Attached volume $VolumeId to instance $InstanceId as $Device." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
