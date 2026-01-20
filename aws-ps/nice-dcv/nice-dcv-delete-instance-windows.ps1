<#
.SYNOPSIS
    Terminate and clean up a NICE DCV Windows EC2 instance.
.DESCRIPTION
    This script terminates a Windows EC2 instance running NICE DCV and deletes associated resources.
.PARAMETER InstanceId
    The EC2 instance ID.
.EXAMPLE
    .\nice-dcv-delete-instance-windows.ps1 -InstanceId i-12345678
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
    Remove-EC2Instance -InstanceId $InstanceId -Force
    Write-Host "Terminated Windows DCV instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to terminate instance: $_"
    exit 1
}
