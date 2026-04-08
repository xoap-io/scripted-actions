<#
.SYNOPSIS
    Enables versioning on an AWS S3 Bucket.

.DESCRIPTION
    This script enables versioning on a specified S3 bucket using the AWS CLI.
    Uses the following AWS CLI command:
    aws s3api put-bucket-versioning

.PARAMETER AwsBucketName
    The name of the S3 bucket.

.EXAMPLE
    .\aws-cli-enable-s3-versioning.ps1 -AwsBucketName "my-bucket"

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
    https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-versioning.html

.COMPONENT
    AWS CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the S3 bucket")]
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
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
