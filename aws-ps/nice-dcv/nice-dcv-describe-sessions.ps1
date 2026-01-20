<#
.SYNOPSIS
    List active NICE DCV sessions on an instance.
.DESCRIPTION
    This script lists active DCV sessions using DCV admin tools via SSM or SSH.
.PARAMETER InstanceId
    The EC2 instance ID.
.EXAMPLE
    .\nice-dcv-describe-sessions.ps1 -InstanceId i-12345678
.LINK
    https://docs.aws.amazon.com/dcv/latest/adminguide/managing-sessions.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId
)

$ErrorActionPreference = 'Stop'
try {
    $commands = @('dcv list-sessions')
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "DCV session list command sent to instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to list DCV sessions: $_"
    exit 1
}
