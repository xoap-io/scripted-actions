<#
.SYNOPSIS
    Enable or disable detailed monitoring for an EC2 instance.

.DESCRIPTION
    This script enables or disables detailed CloudWatch monitoring for an EC2 instance using the Enable-EC2InstanceMonitoring and Disable-EC2InstanceMonitoring cmdlets from AWS.Tools.EC2.

.PARAMETER InstanceId
    The ID of the EC2 instance to update monitoring for.

.PARAMETER EnableMonitoring
    Switch to enable detailed monitoring. If not specified, monitoring is disabled.

.EXAMPLE
    .\aws-ps-monitor-instance.ps1 -InstanceId i-12345678 -EnableMonitoring

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

    [Parameter(HelpMessage = "Switch to enable detailed monitoring. If not specified, monitoring is disabled.")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
