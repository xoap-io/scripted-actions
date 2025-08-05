<#
.SYNOPSIS
    Remotely install and configure NICE DCV on a Linux EC2 instance via SSM.
.DESCRIPTION
    This script uses AWS SSM to run the official NICE DCV installation commands on a Linux EC2 instance.
.PARAMETER InstanceId
    The EC2 instance ID.
.EXAMPLE
    .\nice-dcv-install-linux.ps1 -InstanceId i-12345678
.LINK
    https://docs.aws.amazon.com/dcv/latest/userguide/setting-up-installing-linux.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId
)

$ErrorActionPreference = 'Stop'
try {
    $commands = @(
        'sudo yum update -y',
        'curl -O https://d1uj6qtbmh3dt5.cloudfront.net/NICE-DCV-Linux-x86_64.tgz',
        'tar -xzf NICE-DCV-Linux-x86_64.tgz',
        'cd NICE-DCV-*-x86_64',
        'sudo ./install.sh'
    )
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "NICE DCV installation initiated on instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to install NICE DCV: $_"
    exit 1
}
