<#
.SYNOPSIS
    Enable VPC Flow Logs for a VPC using the AWS CLI.

.DESCRIPTION
    Creates VPC Flow Logs for the specified VPC and delivers them to an Amazon S3
    bucket, CloudWatch Logs log group, or Kinesis Data Firehose delivery stream.
    Uses the AWS CLI command: aws ec2 create-flow-logs.

.PARAMETER Region
    The AWS region where the VPC resides.

.PARAMETER VpcId
    The ID of the VPC for which to enable flow logs.

.PARAMETER LogDestinationType
    The destination type for the flow logs: cloud-watch-logs, s3, or
    kinesis-data-firehose. Default is s3.

.PARAMETER LogDestination
    The ARN of the destination (S3 bucket, CloudWatch log group, or Firehose
    delivery stream). Required.

.PARAMETER TrafficType
    The type of traffic to capture: ACCEPT, REJECT, or ALL. Default is ALL.

.PARAMETER DeliverLogsPermissionArn
    The ARN of the IAM role that allows CloudWatch Logs to publish flow log data.
    Required when LogDestinationType is cloud-watch-logs.

.EXAMPLE
    .\aws-cli-enable-vpc-flow-logs.ps1 -Region "us-east-1" -VpcId "vpc-0a1b2c3d4e5f67890" -LogDestinationType s3 -LogDestination "arn:aws:s3:::my-flow-logs-bucket"

.EXAMPLE
    .\aws-cli-enable-vpc-flow-logs.ps1 -Region "eu-west-1" -VpcId "vpc-0fedcba9876543210" -LogDestinationType cloud-watch-logs -LogDestination "arn:aws:logs:eu-west-1:123456789012:log-group:/vpc/flow-logs" -DeliverLogsPermissionArn "arn:aws:iam::123456789012:role/FlowLogsRole"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-flow-logs.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region where the VPC resides.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC for which to enable flow logs.")]
    [ValidatePattern('^vpc-[a-f0-9]{8,17}$')]
    [string]$VpcId,

    [Parameter(Mandatory = $false, HelpMessage = "Destination type: cloud-watch-logs, s3, or kinesis-data-firehose. Default is s3.")]
    [ValidateSet('cloud-watch-logs', 's3', 'kinesis-data-firehose')]
    [string]$LogDestinationType = 's3',

    [Parameter(Mandatory = $true, HelpMessage = "ARN of the destination (S3 bucket, CloudWatch log group, or Firehose stream).")]
    [ValidateNotNullOrEmpty()]
    [string]$LogDestination,

    [Parameter(Mandatory = $false, HelpMessage = "Traffic type to capture: ACCEPT, REJECT, or ALL. Default is ALL.")]
    [ValidateSet('ACCEPT', 'REJECT', 'ALL')]
    [string]$TrafficType = 'ALL',

    [Parameter(Mandatory = $false, HelpMessage = "IAM role ARN for CloudWatch Logs delivery. Required for cloud-watch-logs destination.")]
    [string]$DeliverLogsPermissionArn
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

# Validate DeliverLogsPermissionArn requirement for CloudWatch destination
if ($LogDestinationType -eq 'cloud-watch-logs' -and -not $DeliverLogsPermissionArn) {
    Write-Host "❌ DeliverLogsPermissionArn is required when LogDestinationType is 'cloud-watch-logs'." -ForegroundColor Red
    exit 1
}

try {
    Write-Host "🚀 Starting VPC Flow Logs Setup" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    Write-Host "🔍 Verifying VPC '$VpcId'..." -ForegroundColor Cyan
    $null = aws ec2 describe-vpcs --region $Region --vpc-ids $VpcId --output json 2>&1
    if ($LASTEXITCODE -ne 0) { throw "VPC '$VpcId' not found or not accessible." }
    Write-Host "✅ VPC verified." -ForegroundColor Green

    Write-Host "🔧 Creating flow logs for VPC '$VpcId'..." -ForegroundColor Cyan

    $awsArgs = @(
        'ec2', 'create-flow-logs',
        '--region', $Region,
        '--resource-type', 'VPC',
        '--resource-ids', $VpcId,
        '--traffic-type', $TrafficType,
        '--log-destination-type', $LogDestinationType,
        '--log-destination', $LogDestination,
        '--output', 'json'
    )

    if ($DeliverLogsPermissionArn) {
        $awsArgs += @('--deliver-logs-permission-arn', $DeliverLogsPermissionArn)
    }

    $result = & aws @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create flow logs: $result"
    }

    $data = $result | ConvertFrom-Json

    if ($data.Unsuccessful -and $data.Unsuccessful.Count -gt 0) {
        $err = $data.Unsuccessful[0].Error
        throw "Flow log creation unsuccessful: $($err.Code) - $($err.Message)"
    }

    Write-Host "✅ VPC Flow Logs enabled successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  VPC ID:             $VpcId" -ForegroundColor Cyan
    Write-Host "  Flow Log ID(s):     $($data.FlowLogIds -join ', ')" -ForegroundColor Cyan
    Write-Host "  Destination type:   $LogDestinationType" -ForegroundColor Cyan
    Write-Host "  Destination:        $LogDestination" -ForegroundColor Cyan
    Write-Host "  Traffic type:       $TrafficType" -ForegroundColor Cyan

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - View flow logs: aws ec2 describe-flow-logs --filter Name=resource-id,Values=$VpcId --region $Region" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
