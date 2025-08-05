<#
.SYNOPSIS
    Add DCV port rules to an existing security group.
.DESCRIPTION
    This script adds DCV TCP/UDP port rules to an existing security group.
.PARAMETER SecurityGroupId
    The security group ID.
.PARAMETER DcvPort
    The DCV port (default 8443).
.EXAMPLE
    .\nice-dcv-authorize-dcv-ports.ps1 -SecurityGroupId sg-12345678 -DcvPort 8443
.LINK
    https://docs.aws.amazon.com/dcv/latest/userguide/setting-up-installing-linux.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,
    [Parameter()]
    [ValidateRange(1024,65535)]
    [int]$DcvPort = 8443
)

$ErrorActionPreference = 'Stop'
try {
    Grant-EC2SecurityGroupIngress -GroupId $SecurityGroupId -IpProtocol 'tcp' -FromPort $DcvPort -ToPort $DcvPort -CidrIp '0.0.0.0/0'
    Grant-EC2SecurityGroupIngress -GroupId $SecurityGroupId -IpProtocol 'udp' -FromPort $DcvPort -ToPort $DcvPort -CidrIp '0.0.0.0/0'
    Write-Host "DCV ports authorized in security group $SecurityGroupId." -ForegroundColor Green
} catch {
    Write-Error "Failed to authorize DCV ports: $_"
    exit 1
}
