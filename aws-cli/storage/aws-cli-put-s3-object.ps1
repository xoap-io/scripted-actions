<#
.SYNOPSIS
    Uploads an object to an AWS S3 Bucket.
.DESCRIPTION
    This script uploads a file to an S3 bucket using the latest AWS CLI (v2.16+).
.PARAMETER AwsBucketName
    The name of the S3 bucket.
.PARAMETER FilePath
    The path to the file to upload.
.PARAMETER Key
    The key (object name) in the bucket.
.EXAMPLE
    .\aws-cli-put-s3-object.ps1 -AwsBucketName my-bucket -FilePath ./file.txt -Key file.txt
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsBucketName,
    [Parameter(Mandatory)]
    [string]$FilePath,
    [Parameter(Mandatory)]
    [string]$Key
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws s3api put-object --bucket $AwsBucketName --key $Key --body $FilePath --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Object uploaded successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to upload object: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
