<#
.SYNOPSIS
    Creates an AWS EC2 Network ACL using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script creates a network ACL for a specified VPC.
.PARAMETER VpcId
    The ID of the VPC for the network ACL.
.EXAMPLE
    .\aws-cli-create-network-acl.ps1 -VpcId vpc-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 create-network-acl --vpc-id $VpcId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Network ACL created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create Network ACL: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
