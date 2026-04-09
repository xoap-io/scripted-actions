<#
.SYNOPSIS
    Restore a resource from an AWS Backup recovery point using the AWS CLI.

.DESCRIPTION
    Initiates an AWS Backup restore job from a specified recovery point ARN.
    Uses the AWS CLI command: aws backup start-restore-job.
    The restore metadata must match the resource type being restored (e.g. EC2,
    EBS, RDS). Outputs the RestoreJobId on success.

.PARAMETER Region
    The AWS region in which to run the restore job.

.PARAMETER RecoveryPointArn
    The ARN of the recovery point to restore from.

.PARAMETER IamRoleArn
    The ARN of the IAM role that AWS Backup assumes for the restore operation.

.PARAMETER ResourceType
    The type of resource to restore: EC2, EBS, RDS, DynamoDB, EFS, or S3.

.PARAMETER RestoreMetadata
    A JSON string or path to a JSON file containing the resource-specific restore
    configuration metadata. Keys vary by resource type (see AWS Backup documentation).

.PARAMETER IdempotencyToken
    A unique string to ensure idempotency of the restore request. Auto-generated if omitted.

.EXAMPLE
    .\aws-cli-restore-from-backup.ps1 -Region "us-east-1" -RecoveryPointArn "arn:aws:ec2:us-east-1::image/ami-0abc1234def56789" -IamRoleArn "arn:aws:iam::123456789012:role/BackupRole" -ResourceType EC2 -RestoreMetadata '{"subnetId":"subnet-0a1b2c3d","instanceType":"t3.micro"}'

.EXAMPLE
    .\aws-cli-restore-from-backup.ps1 -Region "eu-west-1" -RecoveryPointArn "arn:aws:rds:eu-west-1:123456789012:snapshot:rds-snap" -IamRoleArn "arn:aws:iam::123456789012:role/BackupRole" -ResourceType RDS -RestoreMetadata "C:\restore\rds-meta.json"

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
    https://docs.aws.amazon.com/cli/latest/reference/backup/start-restore-job.html

.COMPONENT
    AWS CLI Backup
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to run the restore job.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The ARN of the recovery point to restore from.")]
    [ValidateNotNullOrEmpty()]
    [string]$RecoveryPointArn,

    [Parameter(Mandatory = $true, HelpMessage = "The ARN of the IAM role that AWS Backup assumes for the restore.")]
    [ValidateNotNullOrEmpty()]
    [string]$IamRoleArn,

    [Parameter(Mandatory = $true, HelpMessage = "The type of resource to restore: EC2, EBS, RDS, DynamoDB, EFS, or S3.")]
    [ValidateSet('EC2', 'EBS', 'RDS', 'DynamoDB', 'EFS', 'S3')]
    [string]$ResourceType,

    [Parameter(Mandatory = $true, HelpMessage = "JSON restore metadata string or path to a JSON file.")]
    [ValidateNotNullOrEmpty()]
    [string]$RestoreMetadata,

    [Parameter(Mandatory = $false, HelpMessage = "Unique token for idempotency. Auto-generated if omitted.")]
    [string]$IdempotencyToken
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

# Auto-generate idempotency token if not provided
if (-not $IdempotencyToken) {
    $IdempotencyToken = [System.Guid]::NewGuid().ToString()
}

try {
    Write-Host "🚀 Starting AWS Backup Restore Job" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    # Resolve RestoreMetadata — check if it is a file path
    $metadataJson = $RestoreMetadata
    if (Test-Path $RestoreMetadata -PathType Leaf) {
        Write-Host "🔍 Loading restore metadata from file: $RestoreMetadata" -ForegroundColor Cyan
        $metadataJson = Get-Content -Path $RestoreMetadata -Raw
    }

    # Validate that metadata is valid JSON
    try {
        $metadataJson | ConvertFrom-Json | Out-Null
    } catch {
        throw "RestoreMetadata is not valid JSON: $($_.Exception.Message)"
    }

    Write-Host "🔍 Resource type:       $ResourceType" -ForegroundColor Cyan
    Write-Host "🔍 Recovery point ARN:  $RecoveryPointArn" -ForegroundColor Cyan

    Write-Host "🔧 Starting restore job..." -ForegroundColor Cyan
    $result = aws backup start-restore-job `
        --region $Region `
        --recovery-point-arn $RecoveryPointArn `
        --iam-role-arn $IamRoleArn `
        --resource-type $ResourceType `
        --metadata $metadataJson `
        --idempotency-token $IdempotencyToken `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start restore job: $result"
    }

    $data = $result | ConvertFrom-Json
    Write-Host "✅ Restore job started successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  RestoreJobId:       $($data.RestoreJobId)" -ForegroundColor Cyan
    Write-Host "  Resource type:      $ResourceType" -ForegroundColor Cyan
    Write-Host "  Recovery point:     $RecoveryPointArn" -ForegroundColor Cyan
    Write-Host "  Region:             $Region" -ForegroundColor Cyan

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - Monitor progress: aws backup describe-restore-job --restore-job-id $($data.RestoreJobId) --region $Region" -ForegroundColor Yellow
    Write-Host "  - List recent jobs: aws backup list-restore-jobs --region $Region" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
