
<#!
.SYNOPSIS
    Stops an AWS EC2 instance using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script robustly stops an EC2 instance, with improved error handling and output. Compatible with AWS CLI v2.16+ (2025).

.PARAMETER InstanceId
    The ID of the AWS EC2 instance to stop.

.EXAMPLE
    .\aws-cli-stop-instance.ps1 -InstanceId i-1234567890abcdef0

.LINK
    https://github.com/xoap-io/scripted-actions
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws ec2 stop-instances --instance-ids $InstanceId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "EC2 instance stopped successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to stop EC2 instance: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
