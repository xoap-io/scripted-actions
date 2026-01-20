<#
.SYNOPSIS
    Creates an AWS EBS Volume.
.DESCRIPTION
    This script creates an EBS volume using the latest AWS CLI (v2.16+).
.PARAMETER AvailabilityZone
    The availability zone for the volume.
.PARAMETER Size
    The size of the volume in GiB.
.EXAMPLE
    .\aws-cli-create-ebs-volume.ps1 -AvailabilityZone us-east-1a -Size 10
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AvailabilityZone,
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+$')]
    [int]$Size
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 create-volume --availability-zone $AvailabilityZone --size $Size --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "EBS volume created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create EBS volume: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
