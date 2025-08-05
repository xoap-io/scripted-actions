<#
.SYNOPSIS
    Deletes an AWS S3 Bucket.
.DESCRIPTION
    This script deletes an AWS S3 Bucket using the latest AWS CLI (v2.16+).
.PARAMETER AwsBucketName
    The name of the S3 bucket to delete.
.EXAMPLE
    .\aws-cli-delete-s3-bucket.ps1 -AwsBucketName my-bucket
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
    $result = aws s3api delete-bucket --bucket $AwsBucketName --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "S3 bucket deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete S3 bucket: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
