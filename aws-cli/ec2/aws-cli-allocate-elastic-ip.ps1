
<#!
.SYNOPSIS
    Associates an AWS Elastic IP with an EC2 instance using the latest AWS CLI (v2+).

.DESCRIPTION
    This script robustly associates an Elastic IP with an EC2 instance, using improved error handling and output. It checks for required parameters, validates AWS CLI presence, and provides clear feedback. Compatible with AWS CLI v2.16+ (2025).

.PARAMETER InstanceId
    The ID of the EC2 instance to associate the Elastic IP with.
.PARAMETER AllocationId
    The allocation ID of the Elastic IP to associate.

.EXAMPLE
    .\aws-cli-allocate-elastic-ip.ps1 -InstanceId i-1234567890abcdef0 -AllocationId eipalloc-12345678

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

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws ec2 associate-address --instance-id $InstanceId --allocation-id $AllocationId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Elastic IP associated successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to associate Elastic IP: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
