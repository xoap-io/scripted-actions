<#
.SYNOPSIS
    Start a NICE DCV Windows EC2 instance.
.DESCRIPTION
    This script starts a Windows EC2 instance running NICE DCV.
.PARAMETER InstanceId
    The EC2 instance ID.
.EXAMPLE
    .\nice-dcv-start-instance-windows.ps1 -InstanceId i-12345678
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
    Start-EC2Instance -InstanceId $InstanceId
    Write-Host "Started Windows DCV instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to start instance: $_"
    exit 1
}
