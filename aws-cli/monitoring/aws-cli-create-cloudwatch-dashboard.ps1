<#
.SYNOPSIS
    Creates an Amazon CloudWatch dashboard using the AWS CLI.

.DESCRIPTION
    This script creates a CloudWatch dashboard. When instance IDs are provided
    it automatically generates a dashboard body containing EC2 CPUUtilization
    widgets for each instance. Alternatively a fully custom dashboard JSON body
    can be supplied directly. The dashboard is created (or replaced if it
    already exists) using the AWS CLI.
    Uses the following AWS CLI command:
    aws cloudwatch put-dashboard

.PARAMETER Region
    The AWS region in which to create the dashboard (e.g. us-east-1).

.PARAMETER DashboardName
    The name of the CloudWatch dashboard.

.PARAMETER InstanceIds
    Optional comma-separated EC2 instance IDs. A CPUUtilization widget is
    generated for each instance (e.g. "i-0abc123,i-0def456").

.PARAMETER DashboardJson
    Optional complete dashboard body JSON. When provided this is used directly
    and InstanceIds is ignored.

.EXAMPLE
    .\aws-cli-create-cloudwatch-dashboard.ps1 `
        -Region "us-east-1" `
        -DashboardName "EC2-Overview" `
        -InstanceIds "i-0123456789abcdef0,i-0fedcba9876543210"

.EXAMPLE
    .\aws-cli-create-cloudwatch-dashboard.ps1 `
        -Region "eu-west-1" `
        -DashboardName "Custom-Ops-Dashboard" `
        -DashboardJson (Get-Content -Raw .\my-dashboard.json)

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
    https://docs.aws.amazon.com/cli/latest/reference/cloudwatch/put-dashboard.html

.COMPONENT
    AWS CLI Monitoring
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to create the dashboard (e.g. us-east-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the CloudWatch dashboard.")]
    [ValidateNotNullOrEmpty()]
    [string]$DashboardName,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated EC2 instance IDs to add CPU widgets for.")]
    [string]$InstanceIds,

    [Parameter(Mandatory = $false, HelpMessage = "Custom dashboard body JSON. When provided, InstanceIds is ignored.")]
    [string]$DashboardJson
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Creating CloudWatch dashboard: $DashboardName" -ForegroundColor Green

    # Build the dashboard body
    if ($DashboardJson) {
        Write-Host "🔍 Using supplied custom dashboard JSON." -ForegroundColor Cyan
        $dashboardBody = $DashboardJson
    } else {
        Write-Host "🔧 Generating dashboard body..." -ForegroundColor Cyan

        $widgets = @()
        $x = 0
        $y = 0

        if ($InstanceIds) {
            $idList = $InstanceIds -split ',' | ForEach-Object { $_.Trim() }
            foreach ($instanceId in $idList) {
                $widget = @{
                    type       = 'metric'
                    x          = $x
                    y          = $y
                    width      = 12
                    height     = 6
                    properties = @{
                        title   = "CPU Utilization - $instanceId"
                        metrics = @(
                            @('AWS/EC2', 'CPUUtilization', 'InstanceId', $instanceId)
                        )
                        view    = 'timeSeries'
                        stat    = 'Average'
                        period  = 300
                        region  = $Region
                    }
                }
                $widgets += $widget
                $x += 12
                if ($x -ge 24) {
                    $x = 0
                    $y += 6
                }
            }
        }

        if ($widgets.Count -eq 0) {
            # Default empty dashboard with a text widget
            $widgets += @{
                type       = 'text'
                x          = 0
                y          = 0
                width      = 24
                height     = 3
                properties = @{
                    markdown = "## $DashboardName`n`nAdd widgets to this dashboard via the AWS Console or re-run this script with -InstanceIds."
                }
            }
        }

        $dashboardBody = (@{ widgets = $widgets } | ConvertTo-Json -Depth 10 -Compress)
    }

    Write-Host "🔧 Pushing dashboard to CloudWatch..." -ForegroundColor Cyan

    $result = aws cloudwatch put-dashboard `
        --region $Region `
        --dashboard-name $DashboardName `
        --dashboard-body $dashboardBody `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create CloudWatch dashboard: $result"
    }

    $resultData = $result | ConvertFrom-Json

    # Construct the dashboard ARN
    $accountId = (aws sts get-caller-identity --query Account --output text 2>&1)
    $dashboardArn = "arn:aws:cloudwatch::${accountId}:dashboard/$DashboardName"

    Write-Host "✅ CloudWatch dashboard created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   DashboardName : $DashboardName"
    Write-Host "   DashboardArn  : $dashboardArn"

    if ($resultData.DashboardValidationMessages -and $resultData.DashboardValidationMessages.Count -gt 0) {
        Write-Host "⚠️  Validation messages:" -ForegroundColor Yellow
        $resultData.DashboardValidationMessages | ForEach-Object {
            Write-Host "   - $($_.Message)"
        }
    }

    Write-Host "💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   View your dashboard at: https://$Region.console.aws.amazon.com/cloudwatch/home?region=$Region#dashboards:name=$DashboardName"
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
