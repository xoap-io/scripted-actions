<#
.SYNOPSIS
    Creates a CloudWatch metric alarm using AWS.Tools.CloudWatch.

.DESCRIPTION
    This script creates a CloudWatch metric alarm using the Write-CWMetricAlarm
    cmdlet from AWS.Tools.CloudWatch. Alarms monitor a specified metric and trigger
    actions (e.g. SNS notifications) when the metric crosses a defined threshold.
    Dimensions can be passed as comma-separated "Name=Key,Value=Val" pairs.

.PARAMETER Region
    The AWS region to create the CloudWatch alarm in (e.g. eu-central-1).

.PARAMETER AlarmName
    The name for the CloudWatch alarm.

.PARAMETER MetricName
    The name of the CloudWatch metric to monitor (e.g. CPUUtilization).

.PARAMETER Namespace
    The namespace of the CloudWatch metric (e.g. AWS/EC2).

.PARAMETER Statistic
    The statistic to apply to the metric: Average (default), Sum, Minimum,
    Maximum, or SampleCount.

.PARAMETER Period
    The period in seconds over which the statistic is applied (10-86400, default 300).

.PARAMETER EvaluationPeriods
    The number of consecutive periods the metric must breach the threshold before
    the alarm fires (1-100, default 1).

.PARAMETER Threshold
    The threshold value against which the metric statistic is compared.

.PARAMETER ComparisonOperator
    The comparison to use between the metric statistic and the threshold:
    GreaterThanThreshold, GreaterThanOrEqualToThreshold,
    LessThanThreshold, or LessThanOrEqualToThreshold.

.PARAMETER TreatMissingData
    How to treat missing data points: missing (default), ignore,
    breaching, or notBreaching.

.PARAMETER AlarmActions
    Optional array of SNS topic ARNs or other action ARNs to trigger when the
    alarm state is ALARM.

.PARAMETER Dimensions
    Optional comma-separated dimension pairs in the format "Name=InstanceId,Value=i-1234567890abcdef0".
    Multiple dimensions separated by semicolons.

.PARAMETER AlarmDescription
    Optional description for the CloudWatch alarm.

.EXAMPLE
    .\aws-ps-create-cloudwatch-alarm.ps1 -Region eu-central-1 -AlarmName "HighCPU" -MetricName CPUUtilization -Namespace AWS/EC2 -Threshold 80 -ComparisonOperator GreaterThanThreshold -Dimensions "Name=InstanceId,Value=i-1234567890abcdef0"
    Creates a CloudWatch alarm for EC2 CPU utilization exceeding 80%.

.EXAMPLE
    .\aws-ps-create-cloudwatch-alarm.ps1 -Region us-east-1 -AlarmName "LowDiskSpace" -MetricName disk_used_percent -Namespace CWAgent -Statistic Average -Period 60 -EvaluationPeriods 3 -Threshold 90 -ComparisonOperator GreaterThanThreshold -TreatMissingData breaching -AlarmActions @("arn:aws:sns:us-east-1:123456789012:AlertTopic") -AlarmDescription "Alert when disk usage exceeds 90%"
    Creates a CloudWatch alarm with SNS notification for disk usage.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.CloudWatch

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/items/Write-CWMetricAlarm.html

.COMPONENT
    AWS PowerShell CloudWatch
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region to create the CloudWatch alarm in (e.g. eu-central-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the CloudWatch alarm.")]
    [ValidateNotNullOrEmpty()]
    [string]$AlarmName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the CloudWatch metric to monitor (e.g. CPUUtilization).")]
    [ValidateNotNullOrEmpty()]
    [string]$MetricName,

    [Parameter(Mandatory = $true, HelpMessage = "The namespace of the CloudWatch metric (e.g. AWS/EC2).")]
    [ValidateNotNullOrEmpty()]
    [string]$Namespace,

    [Parameter(HelpMessage = "The statistic to apply to the metric (default: Average).")]
    [ValidateSet('Average', 'Sum', 'Minimum', 'Maximum', 'SampleCount')]
    [string]$Statistic = 'Average',

    [Parameter(HelpMessage = "The period in seconds over which the statistic is applied (10-86400, default 300).")]
    [ValidateRange(10, 86400)]
    [int]$Period = 300,

    [Parameter(HelpMessage = "The number of consecutive periods the metric must breach the threshold (1-100, default 1).")]
    [ValidateRange(1, 100)]
    [int]$EvaluationPeriods = 1,

    [Parameter(Mandatory = $true, HelpMessage = "The threshold value to compare the metric statistic against.")]
    [double]$Threshold,

    [Parameter(Mandatory = $true, HelpMessage = "The comparison operator: GreaterThanThreshold, GreaterThanOrEqualToThreshold, LessThanThreshold, LessThanOrEqualToThreshold.")]
    [ValidateSet('GreaterThanThreshold', 'GreaterThanOrEqualToThreshold', 'LessThanThreshold', 'LessThanOrEqualToThreshold')]
    [string]$ComparisonOperator,

    [Parameter(HelpMessage = "How to treat missing data points: missing (default), ignore, breaching, notBreaching.")]
    [ValidateSet('missing', 'ignore', 'breaching', 'notBreaching')]
    [string]$TreatMissingData = 'missing',

    [Parameter(HelpMessage = "Optional array of SNS topic ARNs to notify when the alarm state is ALARM.")]
    [string[]]$AlarmActions,

    [Parameter(HelpMessage = "Optional semicolon-separated dimension pairs (e.g. 'Name=InstanceId,Value=i-1234567890abcdef0').")]
    [string]$Dimensions,

    [Parameter(HelpMessage = "Optional description for the CloudWatch alarm.")]
    [string]$AlarmDescription
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting CloudWatch alarm creation" -ForegroundColor Green
    Write-Host "🔍 Importing AWS.Tools.CloudWatch module..." -ForegroundColor Cyan
    Import-Module AWS.Tools.CloudWatch -ErrorAction Stop

    # Build dimensions list
    $cwDimensions = [System.Collections.Generic.List[Amazon.CloudWatch.Model.Dimension]]::new()
    if ($Dimensions) {
        foreach ($dimPair in ($Dimensions -split ';')) {
            $dimPair = $dimPair.Trim()
            $parts   = @{}
            foreach ($kv in ($dimPair -split ',')) {
                $kv = $kv.Trim()
                if ($kv -match '^Name=(.+)$') {
                    $parts['Name'] = $Matches[1].Trim()
                }
                elseif ($kv -match '^Value=(.+)$') {
                    $parts['Value'] = $Matches[1].Trim()
                }
            }
            if ($parts.ContainsKey('Name') -and $parts.ContainsKey('Value')) {
                $dim       = [Amazon.CloudWatch.Model.Dimension]::new()
                $dim.Name  = $parts['Name']
                $dim.Value = $parts['Value']
                $cwDimensions.Add($dim)
                Write-Host "   Dimension: $($dim.Name) = $($dim.Value)" -ForegroundColor Gray
            }
        }
    }

    Write-Host "🔧 Creating CloudWatch alarm '$AlarmName'..." -ForegroundColor Cyan

    $createParams = @{
        AlarmName          = $AlarmName
        MetricName         = $MetricName
        Namespace          = $Namespace
        Statistic          = $Statistic
        Period             = $Period
        EvaluationPeriods  = $EvaluationPeriods
        Threshold          = $Threshold
        ComparisonOperator = $ComparisonOperator
        TreatMissingData   = $TreatMissingData
        Region             = $Region
    }
    if ($cwDimensions.Count -gt 0) {
        $createParams['Dimension'] = $cwDimensions
    }
    if ($AlarmActions) {
        $createParams['AlarmAction'] = $AlarmActions
    }
    if ($AlarmDescription) {
        $createParams['AlarmDescription'] = $AlarmDescription
    }

    Write-CWMetricAlarm @createParams

    # Retrieve the created alarm to display details
    $alarm = Get-CWAlarm -AlarmName $AlarmName -Region $Region

    Write-Host "✅ CloudWatch alarm created successfully." -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   AlarmName:  $($alarm.AlarmName)" -ForegroundColor White
    Write-Host "   AlarmArn:   $($alarm.AlarmArn)" -ForegroundColor White
    Write-Host "   StateValue: $($alarm.StateValue)" -ForegroundColor White
    Write-Host "   Metric:     $Namespace/$MetricName" -ForegroundColor White
    Write-Host "   Threshold:  $ComparisonOperator $Threshold" -ForegroundColor White
    Write-Host "   Region:     $Region" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
