<#
.SYNOPSIS
    Deletes an AWS EBS Volume.
.DESCRIPTION
    This script deletes an EBS volume using the latest AWS CLI (v2.16+).
.PARAMETER VolumeId
    The ID of the EBS volume to delete.
.EXAMPLE
    .\aws-cli-delete-ebs-volume.ps1 -VolumeId vol-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 delete-volume --volume-id $VolumeId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "EBS volume deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete EBS volume: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
