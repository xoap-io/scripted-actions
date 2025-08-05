<#
.SYNOPSIS
    Downloads an object from an AWS S3 Bucket.
.DESCRIPTION
    This script downloads a file from an S3 bucket using the latest AWS CLI (v2.16+).
.PARAMETER AwsBucketName
    The name of the S3 bucket.
.PARAMETER Key
    The key (object name) in the bucket.
.PARAMETER FilePath
    The path to save the downloaded file.
.EXAMPLE
    .\aws-cli-get-s3-object.ps1 -AwsBucketName my-bucket -Key file.txt -FilePath ./file.txt
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsBucketName,
    [Parameter(Mandatory)]
    [string]$Key,
    [Parameter(Mandatory)]
    [string]$FilePath
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws s3api get-object --bucket $AwsBucketName --key $Key --output $FilePath 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Object downloaded successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to download object: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
