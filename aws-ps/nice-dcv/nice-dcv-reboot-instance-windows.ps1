<#
.SYNOPSIS
    Reboot a NICE DCV Windows EC2 instance.
.DESCRIPTION
    This script reboots a Windows EC2 instance running NICE DCV.
.PARAMETER InstanceId
    The EC2 instance ID.
.EXAMPLE
    .\nice-dcv-reboot-instance-windows.ps1 -InstanceId i-12345678
.LINK
    https://docs.aws.amazon.com/dcv/latest/userguide/setting-up-installing-windows.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId
)

$ErrorActionPreference = 'Stop'
try {
    Restart-EC2Instance -InstanceId $InstanceId
    Write-Host "Rebooted Windows DCV instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to reboot instance: $_"
    exit 1
}
