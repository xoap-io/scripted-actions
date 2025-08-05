<#
.SYNOPSIS
    Authorizes an egress rule for an AWS EC2 security group.
.DESCRIPTION
    This script adds an egress rule to a security group using the latest AWS CLI (v2.16+).
.PARAMETER GroupId
    The ID of the security group.
.PARAMETER Protocol
    The protocol (tcp, udp, icmp, all).
.PARAMETER Port
    The port number.
.PARAMETER Cidr
    The CIDR block.
.EXAMPLE
    .\aws-cli-authorize-security-group-egress.ps1 -GroupId sg-12345678 -Protocol tcp -Port 443 -Cidr 0.0.0.0/0
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$GroupId,
    [Parameter(Mandatory)]
    [ValidateSet('tcp','udp','icmp','all')]
    [string]$Protocol,
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{1,5}$')]
    [string]$Port,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Cidr
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 authorize-security-group-egress --group-id $GroupId --protocol $Protocol --port $Port --cidr $Cidr --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Egress rule authorized successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to authorize egress rule: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
