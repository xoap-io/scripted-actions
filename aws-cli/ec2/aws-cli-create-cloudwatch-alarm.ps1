<#
.SYNOPSIS
    Create a CloudWatch metric alarm using the AWS CLI.

.DESCRIPTION
    Creates an Amazon CloudWatch metric alarm that triggers based on a threshold
    comparison for a specified metric. Optionally sends a notification to an SNS
    topic when the alarm state changes. Uses the AWS CLI command:
    aws cloudwatch put-metric-alarm.

.PARAMETER Region
    The AWS region in which to create the alarm.

.PARAMETER AlarmName
    The name of the CloudWatch alarm.

.PARAMETER MetricName
    The name of the metric to monitor (e.g. CPUUtilization).

.PARAMETER Namespace
    The namespace of the metric (e.g. AWS/EC2, AWS/RDS).

.PARAMETER Statistic
    The statistic to apply to the metric. Default is Average.

.PARAMETER Period
    The period in seconds over which the statistic is applied (10-86400). Default is 300.

.PARAMETER EvaluationPeriods
    The number of periods over which data is compared to the threshold. Default is 1.

.PARAMETER Threshold
    The value against which the metric statistic is compared.

.PARAMETER ComparisonOperator
    The arithmetic operation to use when comparing the statistic and threshold.

.PARAMETER TreatMissingData
    How to treat missing data: missing, ignore, breaching, or notBreaching. Default is missing.

.PARAMETER AlarmActions
    The ARN of an SNS topic to notify when the alarm state changes.

.PARAMETER Dimensions
    Metric dimensions in the format "Name=key,Value=val" (e.g. "Name=InstanceId,Value=i-0123456789abcdef").

.PARAMETER AlarmDescription
    A description for the alarm.

.EXAMPLE
    .\aws-cli-create-cloudwatch-alarm.ps1 -Region "us-east-1" -AlarmName "HighCPU" -MetricName "CPUUtilization" -Namespace "AWS/EC2" -Threshold 80 -ComparisonOperator GreaterThanThreshold -Dimensions "Name=InstanceId,Value=i-0123456789abcdef0"

.EXAMPLE
    .\aws-cli-create-cloudwatch-alarm.ps1 -Region "eu-west-1" -AlarmName "LowDiskSpace" -MetricName "FreeStorageSpace" -Namespace "AWS/RDS" -Statistic Minimum -Threshold 5368709120 -ComparisonOperator LessThanThreshold -AlarmActions "arn:aws:sns:eu-west-1:123456789012:AlertTopic"

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
    https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-metric-alarm.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to create the alarm.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the CloudWatch alarm.")]
    [ValidateNotNullOrEmpty()]
    [string]$AlarmName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the metric to monitor (e.g. CPUUtilization).")]
    [ValidateNotNullOrEmpty()]
    [string]$MetricName,

    [Parameter(Mandatory = $true, HelpMessage = "The namespace of the metric (e.g. AWS/EC2).")]
    [ValidateNotNullOrEmpty()]
    [string]$Namespace,

    [Parameter(Mandatory = $false, HelpMessage = "Statistic to apply: Average, Sum, Minimum, Maximum, or SampleCount. Default is Average.")]
    [ValidateSet('Average', 'Sum', 'Minimum', 'Maximum', 'SampleCount')]
    [string]$Statistic = 'Average',

    [Parameter(Mandatory = $false, HelpMessage = "Period in seconds over which the statistic is applied (10-86400). Default is 300.")]
    [ValidateRange(10, 86400)]
    [int]$Period = 300,

    [Parameter(Mandatory = $false, HelpMessage = "Number of periods over which data is compared to the threshold (1-100). Default is 1.")]
    [ValidateRange(1, 100)]
    [int]$EvaluationPeriods = 1,

    [Parameter(Mandatory = $true, HelpMessage = "The threshold value the metric is compared against.")]
    [double]$Threshold,

    [Parameter(Mandatory = $true, HelpMessage = "Comparison operator for the alarm condition.")]
    [ValidateSet('GreaterThanThreshold', 'GreaterThanOrEqualToThreshold', 'LessThanThreshold', 'LessThanOrEqualToThreshold')]
    [string]$ComparisonOperator,

    [Parameter(Mandatory = $false, HelpMessage = "How to treat missing data: missing, ignore, breaching, or notBreaching. Default is missing.")]
    [ValidateSet('missing', 'ignore', 'breaching', 'notBreaching')]
    [string]$TreatMissingData = 'missing',

    [Parameter(Mandatory = $false, HelpMessage = "ARN of an SNS topic to notify when the alarm state changes.")]
    [string]$AlarmActions,

    [Parameter(Mandatory = $false, HelpMessage = "Metric dimensions in the format 'Name=key,Value=val'.")]
    [string]$Dimensions,

    [Parameter(Mandatory = $false, HelpMessage = "A description for the alarm.")]
    [string]$AlarmDescription
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Starting CloudWatch Alarm Creation" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    Write-Host "🔧 Creating CloudWatch alarm '$AlarmName'..." -ForegroundColor Cyan

    $awsArgs = @(
        'cloudwatch', 'put-metric-alarm',
        '--region', $Region,
        '--alarm-name', $AlarmName,
        '--metric-name', $MetricName,
        '--namespace', $Namespace,
        '--statistic', $Statistic,
        '--period', $Period,
        '--evaluation-periods', $EvaluationPeriods,
        '--threshold', $Threshold,
        '--comparison-operator', $ComparisonOperator,
        '--treat-missing-data', $TreatMissingData
    )

    if ($AlarmDescription) { $awsArgs += @('--alarm-description', $AlarmDescription) }
    if ($AlarmActions)     { $awsArgs += @('--alarm-actions', $AlarmActions) }
    if ($Dimensions)       { $awsArgs += @('--dimensions', $Dimensions) }

    $result = & aws @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create CloudWatch alarm: $result"
    }

    Write-Host "✅ CloudWatch alarm '$AlarmName' created successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Alarm name:          $AlarmName" -ForegroundColor Cyan
    Write-Host "  Metric:              $Namespace/$MetricName ($Statistic)" -ForegroundColor Cyan
    Write-Host "  Condition:           $ComparisonOperator $Threshold over ${EvaluationPeriods}x${Period}s" -ForegroundColor Cyan
    Write-Host "  Missing data:        $TreatMissingData" -ForegroundColor Cyan
    if ($AlarmActions) {
        Write-Host "  Alarm action (SNS):  $AlarmActions" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
