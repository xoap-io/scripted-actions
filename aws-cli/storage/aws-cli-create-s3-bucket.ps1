<#
.SYNOPSIS
    Create an AWS S3 Bucket.

.DESCRIPTION
    This script creates an AWS S3 Bucket.
    The script uses the AWS CLI to create the specified AWS S3 Bucket.
    The script uses the following AWS CLI command:
    aws s3api create-bucket --bucket $AwsBucketName --region $AwsBucketRegion
    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    AWS CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AwsBucketName
    Defines the name of the AWS S3 Bucket.

.PARAMETER AwsBucketRegion
    Defines the region of the AWS S3 Bucket.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsBucketName = "myBucketName",
    [Parameter(Mandatory)]
    [ValidateSet('af-south-1','ap-east-1','ap-northeast-1','ap-northeast-2','ap-northeast-3','ap-south-1','ap-southeast-1','ap-southeast-2','ca-central-1','eu-central-1','eu-north-1','eu-south-1','eu-west-1','eu-west-2','eu-west-3','me-south-1','sa-east-1','us-east-1','us-east-2','us-west-1','us-west-2')]
    [string]$AwsBucketRegion = ""
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

aws s3api create-bucket `
    --bucket $AwsBucketName `
    --region $AwsBucketRegion
