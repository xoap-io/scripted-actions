<#
.SYNOPSIS
    Describes AWS EC2 security groups.
.DESCRIPTION
    This script lists or describes security groups using the latest AWS CLI (v2.16+).
.PARAMETER GroupId
    The ID of the security group to describe (optional).
.EXAMPLE
    .\aws-cli-describe-security-groups.ps1 -GroupId sg-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$GroupId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    if ($GroupId) {
        $result = aws ec2 describe-security-groups --group-ids $GroupId --output json 2>&1
    } else {
        $result = aws ec2 describe-security-groups --output json 2>&1
    }
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Security group(s) described successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to describe security group(s): $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
