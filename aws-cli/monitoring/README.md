# Monitoring Scripts

PowerShell scripts for monitoring AWS resources using the AWS CLI. Covers
CloudWatch alarms, CloudWatch dashboards, AWS Cost Explorer queries, and
AWS Budgets with alert notifications.

## Prerequisites

- AWS CLI v2
- Appropriate AWS credentials configured

## Available Scripts

| Script                                    | Description                                                                       |
| ----------------------------------------- | --------------------------------------------------------------------------------- |
| `aws-cli-create-cloudwatch-alarm.ps1`     | Creates a CloudWatch metric alarm with configurable thresholds and SNS actions    |
| `aws-cli-create-cloudwatch-dashboard.ps1` | Creates a CloudWatch dashboard with auto-generated EC2 CPU widgets or custom JSON |
| `aws-cli-get-cost-and-usage.ps1`          | Queries AWS Cost Explorer and exports results as a table, CSV, or JSON            |
| `aws-cli-create-budget.ps1`               | Creates an AWS Budget with a percentage-based alert notification                  |

## Usage Examples

### Create a CloudWatch Alarm

```powershell
.\aws-cli-create-cloudwatch-alarm.ps1 `
    -Region "us-east-1" `
    -AlarmName "HighCPU-WebServer" `
    -MetricName "CPUUtilization" `
    -Namespace "AWS/EC2" `
    -Threshold 80 `
    -ComparisonOperator "GreaterThanThreshold" `
    -AlarmActions "arn:aws:sns:us-east-1:123456789012:ops-alerts" `
    -Dimensions "Name=InstanceId,Value=i-0123456789abcdef0"
```

### Create a CloudWatch Dashboard

```powershell
.\aws-cli-create-cloudwatch-dashboard.ps1 `
    -Region "us-east-1" `
    -DashboardName "EC2-Overview" `
    -InstanceIds "i-0123456789abcdef0,i-0fedcba9876543210"
```

### Query Cost and Usage

```powershell
.\aws-cli-get-cost-and-usage.ps1 `
    -StartDate "2026-01-01" `
    -EndDate "2026-04-01" `
    -Granularity "MONTHLY" `
    -GroupBy "SERVICE" `
    -OutputFormat "CSV"
```

### Create a Budget with Alert

```powershell
.\aws-cli-create-budget.ps1 `
    -AccountId "123456789012" `
    -BudgetName "MonthlyOpsBudget" `
    -BudgetAmount 500 `
    -AlertThresholdPercent 80 `
    -NotificationEmail "ops-team@example.com"
```

## Notes

- Cost Explorer data may have a delay of up to 24 hours.
- Budget alerts are delivered via email when a notification address is provided.
- CloudWatch alarm periods must be a multiple of 60 seconds for most metrics;
  10-second granularity requires detailed monitoring to be enabled on the resource.
- Dashboard names must be unique within an AWS account and region.
