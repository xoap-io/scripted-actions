<#
.SYNOPSIS
    Lists all AWS S3 Buckets.
.DESCRIPTION
    This script lists all S3 buckets using the latest AWS CLI (v2.16+).
.EXAMPLE
    .\aws-cli-list-s3-buckets.ps1
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws s3api list-buckets --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "S3 buckets listed successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to list S3 buckets: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
