<#
.SYNOPSIS
    Creates an Amazon CloudWatch metric alarm using the AWS CLI.

.DESCRIPTION
    This script creates a CloudWatch metric alarm that monitors a specific AWS
    metric and triggers actions when a threshold is breached. Alarm actions
    such as SNS topic notifications can be specified, and metric dimensions
    can be passed to scope the alarm to a particular resource.
    Uses the following AWS CLI command:
    aws cloudwatch put-metric-alarm

.PARAMETER Region
    The AWS region in which to create the alarm (e.g. us-east-1).

.PARAMETER AlarmName
    The name of the CloudWatch alarm.

.PARAMETER MetricName
    The name of the metric to monitor (e.g. CPUUtilization).

.PARAMETER Namespace
    The metric namespace (e.g. AWS/EC2).

.PARAMETER Statistic
    The statistic to apply to the metric.
    Valid values: Average, Sum, Minimum, Maximum, SampleCount. Defaults to Average.

.PARAMETER Period
    The period in seconds over which the statistic is applied (10-86400).
    Defaults to 300.

.PARAMETER EvaluationPeriods
    The number of periods over which data is compared to the threshold (1-100).
    Defaults to 1.

.PARAMETER Threshold
    The value against which the specified statistic is compared.

.PARAMETER ComparisonOperator
    The comparison operator for the alarm condition.
    Valid values: GreaterThanThreshold, GreaterThanOrEqualToThreshold,
    LessThanThreshold, LessThanOrEqualToThreshold.

.PARAMETER TreatMissingData
    How to treat missing data points.
    Valid values: missing, ignore, breaching, notBreaching. Defaults to missing.

.PARAMETER AlarmActions
    Optional comma-separated SNS topic ARNs to notify when the alarm triggers.

.PARAMETER Dimensions
    Optional metric dimensions in "Name=<name>,Value=<value>" format,
    comma-separated for multiple dimensions
    (e.g. "Name=InstanceId,Value=i-0123456789abcdef0").

.PARAMETER AlarmDescription
    An optional description for the alarm.

.EXAMPLE
    .\aws-cli-create-cloudwatch-alarm.ps1 `
        -Region "us-east-1" `
        -AlarmName "HighCPU-MyInstance" `
        -MetricName "CPUUtilization" `
        -Namespace "AWS/EC2" `
        -Threshold 80 `
        -ComparisonOperator "GreaterThanThreshold" `
        -Dimensions "Name=InstanceId,Value=i-0123456789abcdef0"

.EXAMPLE
    .\aws-cli-create-cloudwatch-alarm.ps1 `
        -Region "eu-west-1" `
        -AlarmName "LowDiskSpace-WebServer" `
        -MetricName "disk_used_percent" `
        -Namespace "CWAgent" `
        -Statistic "Average" `
        -Period 300 `
        -EvaluationPeriods 3 `
        -Threshold 90 `
        -ComparisonOperator "GreaterThanOrEqualToThreshold" `
        -TreatMissingData "breaching" `
        -AlarmActions "arn:aws:sns:eu-west-1:123456789012:ops-alerts" `
        -AlarmDescription "Alert when disk usage exceeds 90 percent"

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
    AWS CLI Monitoring
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to create the alarm (e.g. us-east-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the CloudWatch alarm.")]
    [ValidateNotNullOrEmpty()]
    [string]$AlarmName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the metric to monitor (e.g. CPUUtilization).")]
    [ValidateNotNullOrEmpty()]
    [string]$MetricName,

    [Parameter(Mandatory = $true, HelpMessage = "The metric namespace (e.g. AWS/EC2).")]
    [ValidateNotNullOrEmpty()]
    [string]$Namespace,

    [Parameter(Mandatory = $false, HelpMessage = "The statistic to apply to the metric. Defaults to Average.")]
    [ValidateSet('Average', 'Sum', 'Minimum', 'Maximum', 'SampleCount')]
    [string]$Statistic = 'Average',

    [Parameter(Mandatory = $false, HelpMessage = "The evaluation period in seconds (10-86400). Defaults to 300.")]
    [ValidateRange(10, 86400)]
    [int]$Period = 300,

    [Parameter(Mandatory = $false, HelpMessage = "The number of periods to evaluate (1-100). Defaults to 1.")]
    [ValidateRange(1, 100)]
    [int]$EvaluationPeriods = 1,

    [Parameter(Mandatory = $true, HelpMessage = "The threshold value for the alarm condition.")]
    [double]$Threshold,

    [Parameter(Mandatory = $true, HelpMessage = "The comparison operator for the alarm condition.")]
    [ValidateSet('GreaterThanThreshold', 'GreaterThanOrEqualToThreshold', 'LessThanThreshold', 'LessThanOrEqualToThreshold')]
    [string]$ComparisonOperator,

    [Parameter(Mandatory = $false, HelpMessage = "How to treat missing data points. Defaults to missing.")]
    [ValidateSet('missing', 'ignore', 'breaching', 'notBreaching')]
    [string]$TreatMissingData = 'missing',

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated SNS topic ARNs to notify when the alarm fires.")]
    [string]$AlarmActions,

    [Parameter(Mandatory = $false, HelpMessage = "Metric dimensions in 'Name=<n>,Value=<v>' format, comma-separated.")]
    [string]$Dimensions,

    [Parameter(Mandatory = $false, HelpMessage = "An optional description for the alarm.")]
    [string]$AlarmDescription
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Creating CloudWatch alarm: $AlarmName" -ForegroundColor Green

    $createArgs = @(
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
        '--treat-missing-data', $TreatMissingData,
        '--output', 'json'
    )

    if ($AlarmDescription) {
        $createArgs += '--alarm-description', $AlarmDescription
    }

    if ($AlarmActions) {
        $actionList = $AlarmActions -split ',' | ForEach-Object { $_.Trim() }
        $createArgs += '--alarm-actions'
        $createArgs += $actionList
    }

    if ($Dimensions) {
        $dimList = $Dimensions -split ',' | ForEach-Object { $_.Trim() }
        $createArgs += '--dimensions'
        $createArgs += $dimList
    }

    Write-Host "🔧 Creating alarm..." -ForegroundColor Cyan

    $result = aws @createArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create CloudWatch alarm: $result"
    }

    Write-Host "✅ CloudWatch alarm created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   AlarmName          : $AlarmName"
    Write-Host "   MetricName         : $MetricName"
    Write-Host "   Namespace          : $Namespace"
    Write-Host "   Statistic          : $Statistic"
    Write-Host "   Period             : ${Period}s"
    Write-Host "   EvaluationPeriods  : $EvaluationPeriods"
    Write-Host "   Threshold          : $Threshold"
    Write-Host "   ComparisonOperator : $ComparisonOperator"
    Write-Host "   TreatMissingData   : $TreatMissingData"

    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   View alarm state with: aws cloudwatch describe-alarms --region $Region --alarm-names '$AlarmName'"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
