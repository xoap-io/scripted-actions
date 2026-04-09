<#
.SYNOPSIS
    Enable cross-region S3 replication on a source bucket using the AWS CLI.

.DESCRIPTION
    Configures Amazon S3 Cross-Region Replication (CRR) from a source bucket to a
    destination bucket in another region. Both buckets must have versioning enabled
    before replication can be configured. Uses the AWS CLI command:
    aws s3api put-bucket-replication.
    The script verifies versioning status and applies the replication configuration.

.PARAMETER Region
    The AWS region of the source bucket.

.PARAMETER SourceBucket
    The name of the source S3 bucket.

.PARAMETER DestinationBucket
    The name of the destination S3 bucket.

.PARAMETER DestinationRegion
    The AWS region of the destination bucket.

.PARAMETER RoleArn
    The ARN of the IAM role that Amazon S3 can assume to replicate objects.

.PARAMETER ReplicationPrefix
    Replicate only objects whose key begins with this prefix. If omitted,
    all objects in the source bucket are replicated.

.EXAMPLE
    .\aws-cli-enable-s3-replication.ps1 -Region "us-east-1" -SourceBucket "prod-data" -DestinationBucket "dr-prod-data" -DestinationRegion "us-west-2" -RoleArn "arn:aws:iam::123456789012:role/S3ReplicationRole"

.EXAMPLE
    .\aws-cli-enable-s3-replication.ps1 -Region "eu-west-1" -SourceBucket "app-logs" -DestinationBucket "app-logs-dr" -DestinationRegion "eu-central-1" -RoleArn "arn:aws:iam::123456789012:role/S3ReplicationRole" -ReplicationPrefix "logs/"

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
    https://docs.aws.amazon.com/cli/latest/reference/s3api/put-bucket-replication.html

.COMPONENT
    AWS CLI S3
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region of the source bucket.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the source S3 bucket.")]
    [ValidateNotNullOrEmpty()]
    [string]$SourceBucket,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the destination S3 bucket.")]
    [ValidateNotNullOrEmpty()]
    [string]$DestinationBucket,

    [Parameter(Mandatory = $true, HelpMessage = "The AWS region of the destination bucket.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$DestinationRegion,

    [Parameter(Mandatory = $true, HelpMessage = "The ARN of the IAM role for replication.")]
    [ValidateNotNullOrEmpty()]
    [string]$RoleArn,

    [Parameter(Mandatory = $false, HelpMessage = "Replicate only objects whose key begins with this prefix.")]
    [string]$ReplicationPrefix
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Starting S3 Cross-Region Replication Setup" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    # Verify source bucket versioning
    Write-Host "🔍 Checking versioning on source bucket '$SourceBucket'..." -ForegroundColor Cyan
    $srcVersioning = aws s3api get-bucket-versioning --bucket $SourceBucket --region $Region --output json 2>&1 | ConvertFrom-Json
    if ($srcVersioning.Status -ne 'Enabled') {
        Write-Host "⚠️  Versioning not enabled on source. Enabling now..." -ForegroundColor Yellow
        aws s3api put-bucket-versioning --bucket $SourceBucket --region $Region --versioning-configuration Status=Enabled 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to enable versioning on source bucket." }
        Write-Host "✅ Versioning enabled on source bucket." -ForegroundColor Green
    } else {
        Write-Host "✅ Versioning is already enabled on source bucket." -ForegroundColor Green
    }

    # Verify destination bucket versioning
    Write-Host "🔍 Checking versioning on destination bucket '$DestinationBucket'..." -ForegroundColor Cyan
    $dstVersioning = aws s3api get-bucket-versioning --bucket $DestinationBucket --region $DestinationRegion --output json 2>&1 | ConvertFrom-Json
    if ($dstVersioning.Status -ne 'Enabled') {
        Write-Host "⚠️  Versioning not enabled on destination. Enabling now..." -ForegroundColor Yellow
        aws s3api put-bucket-versioning --bucket $DestinationBucket --region $DestinationRegion --versioning-configuration Status=Enabled 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Failed to enable versioning on destination bucket." }
        Write-Host "✅ Versioning enabled on destination bucket." -ForegroundColor Green
    } else {
        Write-Host "✅ Versioning is already enabled on destination bucket." -ForegroundColor Green
    }

    # Build destination bucket ARN
    $destBucketArn  = "arn:aws:s3:::$DestinationBucket"

    # Build replication configuration
    $ruleFilter = if ($ReplicationPrefix) { @{ Prefix = $ReplicationPrefix } } else { @{ Prefix = '' } }
    $replicationConfig = @{
        Role  = $RoleArn
        Rules = @(
            @{
                ID     = "XOAP-CRR-$(Get-Date -Format 'yyyyMMdd')"
                Status = 'Enabled'
                Filter = $ruleFilter
                Destination = @{
                    Bucket       = $destBucketArn
                    StorageClass = 'STANDARD'
                }
                DeleteMarkerReplication = @{ Status = 'Enabled' }
            }
        )
    }

    $replicationJson = $replicationConfig | ConvertTo-Json -Depth 8 -Compress

    Write-Host "🔧 Applying replication configuration to '$SourceBucket'..." -ForegroundColor Cyan
    $result = aws s3api put-bucket-replication `
        --region $Region `
        --bucket $SourceBucket `
        --replication-configuration $replicationJson 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to set replication configuration: $result"
    }

    Write-Host "✅ Cross-region replication enabled successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Source:             $SourceBucket ($Region)" -ForegroundColor Cyan
    Write-Host "  Destination:        $DestinationBucket ($DestinationRegion)" -ForegroundColor Cyan
    Write-Host "  Prefix filter:      $(if ($ReplicationPrefix) { $ReplicationPrefix } else { '(all objects)' })" -ForegroundColor Cyan
    Write-Host "  IAM Role:           $RoleArn" -ForegroundColor Cyan
    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - Verify replication with: aws s3api get-bucket-replication --bucket $SourceBucket" -ForegroundColor Yellow
    Write-Host "  - New objects will be replicated; existing objects require a S3 Batch Operations job." -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
