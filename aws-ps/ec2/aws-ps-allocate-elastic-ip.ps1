<#
.SYNOPSIS
    Allocate a new Elastic IP address.
.DESCRIPTION
    This script allocates a new Elastic IP address using AWS.Tools.EC2.
.EXAMPLE
    .\aws-ps-allocate-elastic-ip.ps1
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try {
    $eip = New-EC2Address -Domain vpc
    Write-Host "Allocated Elastic IP: $($eip.PublicIp)" -ForegroundColor Green
} catch {
    Write-Error "Failed to allocate Elastic IP: $_"
    exit 1
}
