<#
.SYNOPSIS
    Deletes an AWS EC2 security group using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script deletes a security group by its ID.
.PARAMETER GroupId
    The ID of the security group to delete.
.EXAMPLE
    .\aws-cli-delete-security-group.ps1 -GroupId sg-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$GroupId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 delete-security-group --group-id $GroupId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Security group deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete security group: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
