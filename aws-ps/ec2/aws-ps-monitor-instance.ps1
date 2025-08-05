<#
.SYNOPSIS
    Enable or disable detailed monitoring for an EC2 instance.
.DESCRIPTION
    This script enables or disables detailed monitoring for an EC2 instance using AWS.Tools.EC2.
.PARAMETER InstanceId
    The ID of the EC2 instance.
.PARAMETER EnableMonitoring
    Switch to enable monitoring. If not set, disables monitoring.
.EXAMPLE
    .\aws-ps-monitor-instance.ps1 -InstanceId i-12345678 -EnableMonitoring
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,
    [Parameter()]
    [switch]$EnableMonitoring
)

$ErrorActionPreference = 'Stop'
try {
    if ($EnableMonitoring) {
        Enable-EC2InstanceMonitoring -InstanceId $InstanceId
        Write-Host "Enabled detailed monitoring for instance $InstanceId." -ForegroundColor Green
    } else {
        Disable-EC2InstanceMonitoring -InstanceId $InstanceId
        Write-Host "Disabled detailed monitoring for instance $InstanceId." -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to update monitoring: $_"
    exit 1
}
