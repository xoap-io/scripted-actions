<#
.SYNOPSIS
    Downloads an object from an AWS S3 Bucket.

.DESCRIPTION
    This script downloads a file from an S3 bucket using the AWS CLI.
    Uses the following AWS CLI command:
    aws s3api get-object

.PARAMETER AwsBucketName
    The name of the S3 bucket.

.PARAMETER Key
    The key (object name) in the bucket.

.PARAMETER FilePath
    The path to save the downloaded file.

.EXAMPLE
    .\aws-cli-get-s3-object.ps1 -AwsBucketName "my-bucket" -Key "file.txt" -FilePath "./file.txt"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/s3api/get-object.html

.COMPONENT
    AWS CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the S3 bucket")]
    [string]$AwsBucketName,

    [Parameter(Mandatory = $true, HelpMessage = "The key (object name) in the bucket")]
    [string]$Key,

    [Parameter(Mandatory = $true, HelpMessage = "The path to save the downloaded file")]
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
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
