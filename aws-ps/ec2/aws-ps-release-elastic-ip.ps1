<#
.SYNOPSIS
    Release an Elastic IP address.
.DESCRIPTION
    This script releases an Elastic IP address using AWS.Tools.EC2.
.PARAMETER AllocationId
    The allocation ID of the Elastic IP to release.
.EXAMPLE
    .\aws-ps-release-elastic-ip.ps1 -AllocationId eipalloc-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]{8,}$')]
    [string]$AllocationId
)

$ErrorActionPreference = 'Stop'
try {
    Remove-EC2Address -AllocationId $AllocationId
    Write-Host "Released Elastic IP ($AllocationId)." -ForegroundColor Green
} catch {
    Write-Error "Failed to release Elastic IP: $_"
    exit 1
}
