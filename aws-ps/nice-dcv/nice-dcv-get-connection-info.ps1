<#
.SYNOPSIS
    Output connection details for a DCV instance.
.DESCRIPTION
    This script outputs public IP, port, and user for a DCV instance.
.PARAMETER InstanceId
    The EC2 instance ID.
.PARAMETER DcvPort
    The DCV port (default 8443).
.PARAMETER UserName
    The DCV user name.
.EXAMPLE
    .\nice-dcv-get-connection-info.ps1 -InstanceId i-12345678 -DcvPort 8443 -UserName dcvuser
.LINK
    https://docs.aws.amazon.com/dcv/latest/userguide/connecting-to-session.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,
    [Parameter()]
    [ValidateRange(1024,65535)]
    [int]$DcvPort = 8443,
    [Parameter()]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName = 'dcvuser'
)

$ErrorActionPreference = 'Stop'
try {
    $instance = Get-EC2Instance -InstanceId $InstanceId | Select-Object -ExpandProperty Instances
    $ip = $instance[0].PublicIpAddress
    Write-Host "DCV Connection Info:" -ForegroundColor Green
    Write-Host "URL: https://${ip}:$DcvPort" -ForegroundColor Cyan
    Write-Host "User: $UserName" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to get DCV connection info: $_"
    exit 1
}
