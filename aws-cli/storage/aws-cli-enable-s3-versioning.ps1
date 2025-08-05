<#
.SYNOPSIS
    Enables versioning on an AWS S3 Bucket.
.DESCRIPTION
    This script enables versioning on a specified S3 bucket using the latest AWS CLI (v2.16+).
.PARAMETER AwsBucketName
    The name of the S3 bucket.
.EXAMPLE
    .\aws-cli-enable-s3-versioning.ps1 -AwsBucketName my-bucket
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsBucketName
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws s3api put-bucket-versioning --bucket $AwsBucketName --versioning-configuration Status=Enabled --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Versioning enabled successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to enable versioning: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
