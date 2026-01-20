<#
.SYNOPSIS
    Uninstall NICE DCV from a Windows EC2 instance via SSM.
.DESCRIPTION
    This script uses AWS SSM to uninstall NICE DCV from a Windows EC2 instance.
.PARAMETER InstanceId
    The EC2 instance ID.
.EXAMPLE
    .\nice-dcv-uninstall-windows.ps1 -InstanceId i-12345678
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
        'Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE \"%DCV%\"" | ForEach-Object { $_.Uninstall() }'
    )
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "NICE DCV uninstall command sent to Windows instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to uninstall NICE DCV: $_"
    exit 1
}
