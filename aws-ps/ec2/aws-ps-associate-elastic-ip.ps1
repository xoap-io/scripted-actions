<#
.SYNOPSIS
    Associate an Elastic IP with an EC2 instance.
.DESCRIPTION
    This script associates an Elastic IP address with an EC2 instance using AWS.Tools.EC2.
.PARAMETER InstanceId
    The ID of the EC2 instance.
.PARAMETER AllocationId
    The allocation ID of the Elastic IP.
.EXAMPLE
    .\aws-ps-associate-elastic-ip.ps1 -InstanceId i-12345678 -AllocationId eipalloc-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,
    [Parameter(Mandatory)]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]{8,}$')]
    [string]$AllocationId
)

$ErrorActionPreference = 'Stop'
try {
    $assoc = Register-EC2Address -InstanceId $InstanceId -AllocationId $AllocationId
    Write-Host "Associated Elastic IP ($AllocationId) with instance $InstanceId." -ForegroundColor Green
} catch {
    Write-Error "Failed to associate Elastic IP: $_"
    exit 1
}
