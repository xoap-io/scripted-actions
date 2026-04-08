<#
.SYNOPSIS
    Terminate a NICE DCV session by session ID.

.DESCRIPTION
    This script terminates a DCV session on an EC2 instance by sending the 'dcv close-session' command via AWS Systems Manager using the Send-SSMCommand cmdlet from AWS.Tools.SimpleSystemsManagement.

.PARAMETER InstanceId
    The EC2 instance ID running the DCV session.

.PARAMETER SessionId
    The DCV session ID to terminate.

.EXAMPLE
    .\nice-dcv-terminate-session.ps1 -InstanceId i-12345678 -SessionId session-1234

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.SimpleSystemsManagement

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell NICE DCV
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The EC2 instance ID running the DCV session (e.g. i-12345678abcdef01).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $true, HelpMessage = "The DCV session ID to terminate.")]
    [string]$SessionId
)

$ErrorActionPreference = 'Stop'

try {
    $commands = @("dcv close-session $SessionId")
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "DCV session $SessionId termination command sent to instance $InstanceId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
