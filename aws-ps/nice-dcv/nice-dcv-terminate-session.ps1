<#
.SYNOPSIS
    Terminate a NICE DCV session by session ID.
.DESCRIPTION
    This script terminates a DCV session using DCV admin tools via SSM or SSH.
.PARAMETER InstanceId
    The EC2 instance ID.
.PARAMETER SessionId
    The DCV session ID to terminate.
.EXAMPLE
    .\nice-dcv-terminate-session.ps1 -InstanceId i-12345678 -SessionId session-1234
.LINK
    https://docs.aws.amazon.com/dcv/latest/adminguide/managing-sessions.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,
    [Parameter(Mandatory)]
    [string]$SessionId
)

$ErrorActionPreference = 'Stop'
try {
    $commands = @("dcv close-session $SessionId")
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "DCV session $SessionId termination command sent to instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to terminate DCV session: $_"
    exit 1
}
