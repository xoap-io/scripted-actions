<#
.SYNOPSIS
    Create a DCV user on the instance (Linux or Windows).
.DESCRIPTION
    This script creates a DCV user using SSM or SSH.
.PARAMETER InstanceId
    The EC2 instance ID.
.PARAMETER UserName
    The DCV user name to create.
.EXAMPLE
    .\nice-dcv-create-user.ps1 -InstanceId i-12345678 -UserName dcvuser
.LINK
    https://docs.aws.amazon.com/dcv/latest/adminguide/managing-users.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName
)

$ErrorActionPreference = 'Stop'
try {
    $commands = @("sudo useradd $UserName")
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "DCV user $UserName creation command sent to instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to create DCV user: $_"
    exit 1
}
