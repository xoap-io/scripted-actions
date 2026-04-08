<#
.SYNOPSIS
    Creates an AWS S3 Bucket.

.DESCRIPTION
    This script creates an AWS S3 Bucket using the AWS CLI.
    Uses the following AWS CLI command:
    aws s3api create-bucket

.PARAMETER AwsBucketName
    Defines the name of the AWS S3 Bucket.

.PARAMETER AwsBucketRegion
    Defines the region of the AWS S3 Bucket.

.EXAMPLE
    .\aws-cli-create-s3-bucket.ps1 -AwsBucketName "my-bucket" -AwsBucketRegion "us-east-1"

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
    https://docs.aws.amazon.com/cli/latest/reference/s3api/create-bucket.html

.COMPONENT
    AWS CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the AWS S3 Bucket")]
    [string]$AwsBucketName,

    [Parameter(Mandatory = $true, HelpMessage = "The region of the AWS S3 Bucket")]
    [ValidateSet('af-south-1','ap-east-1','ap-northeast-1','ap-northeast-2','ap-northeast-3','ap-south-1','ap-southeast-1','ap-southeast-2','ca-central-1','eu-central-1','eu-north-1','eu-south-1','eu-west-1','eu-west-2','eu-west-3','me-south-1','sa-east-1','us-east-1','us-east-2','us-west-1','us-west-2')]
    [string]$AwsBucketRegion
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws s3api create-bucket --bucket $AwsBucketName --region $AwsBucketRegion --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "S3 bucket created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create S3 bucket: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
