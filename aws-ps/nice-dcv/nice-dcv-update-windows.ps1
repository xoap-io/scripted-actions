<#
.SYNOPSIS
    Update NICE DCV on a Windows EC2 instance via SSM.
.DESCRIPTION
    This script uses AWS SSM to update NICE DCV to the latest version on a Windows EC2 instance.
.PARAMETER InstanceId
    The EC2 instance ID.
.EXAMPLE
    .\nice-dcv-update-windows.ps1 -InstanceId i-12345678
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
    $commands = @(
        'Invoke-WebRequest -Uri https://d1uj6qtbmh3dt5.cloudfront.net/NICE-DCV-Windows-x86_64.msi -OutFile C:\NICE-DCV.msi',
        'Start-Process msiexec.exe -ArgumentList "/i C:\NICE-DCV.msi /qn /update" -Wait'
    )
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "NICE DCV update command sent to Windows instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to update NICE DCV: $_"
    exit 1
}
