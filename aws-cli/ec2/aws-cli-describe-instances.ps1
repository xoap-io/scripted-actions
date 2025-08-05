<#
.SYNOPSIS
    Describes AWS EC2 instances using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script lists or describes EC2 instances. Optionally filter by instance ID.
.PARAMETER InstanceId
    The ID of the EC2 instance to describe (optional).
.EXAMPLE
    .\aws-cli-describe-instances.ps1 -InstanceId i-1234567890abcdef0
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    if ($InstanceId) {
        $result = aws ec2 describe-instances --instance-ids $InstanceId --output json 2>&1
    } else {
        $result = aws ec2 describe-instances --output json 2>&1
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "EC2 instance(s) described successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to describe EC2 instance(s): $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
