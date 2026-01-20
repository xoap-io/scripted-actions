<#
.SYNOPSIS
    Lists objects in an AWS S3 Bucket.
.DESCRIPTION
    This script lists objects in a specified S3 bucket using the latest AWS CLI (v2.16+).
.PARAMETER AwsBucketName
    The name of the S3 bucket.
.EXAMPLE
    .\aws-cli-list-s3-objects.ps1 -AwsBucketName my-bucket
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
    $result = aws s3api list-objects-v2 --bucket $AwsBucketName --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Objects listed successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to list objects: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
