<#
.SYNOPSIS
    List and describe EC2 Auto Scaling groups using the AWS CLI.

.DESCRIPTION
    Retrieves information about one or all Auto Scaling groups in the specified
    region using the AWS CLI command: aws autoscaling describe-auto-scaling-groups.
    Displays group name, desired/min/max capacity, health check type, and instance
    lifecycle states.

.PARAMETER Region
    The AWS region to query.

.PARAMETER AutoScalingGroupName
    Filter results to a specific Auto Scaling group name. If omitted, all groups
    in the region are returned.

.PARAMETER OutputFormat
    Output format: Table (formatted display) or JSON (raw CLI output). Default is Table.

.EXAMPLE
    .\aws-cli-describe-auto-scaling-groups.ps1 -Region "us-east-1"

.EXAMPLE
    .\aws-cli-describe-auto-scaling-groups.ps1 -Region "eu-west-1" -AutoScalingGroupName "web-asg" -OutputFormat JSON

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
    https://docs.aws.amazon.com/cli/latest/reference/autoscaling/describe-auto-scaling-groups.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region to query.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Filter results to a specific Auto Scaling group name.")]
    [string]$AutoScalingGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Output format: Table or JSON. Default is Table.")]
    [ValidateSet('Table', 'JSON')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    Write-Host "🚀 Describing Auto Scaling Groups" -ForegroundColor Green
    Write-Host "🔍 Region: $Region" -ForegroundColor Cyan

    # Build command arguments
    $awsArgs = @('autoscaling', 'describe-auto-scaling-groups', '--region', $Region, '--output', 'json')
    if ($AutoScalingGroupName) {
        $awsArgs += @('--auto-scaling-group-names', $AutoScalingGroupName)
    }

    $result = & aws @awsArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to describe Auto Scaling groups: $result"
    }

    $data = $result | ConvertFrom-Json
    $groups = $data.AutoScalingGroups

    if (-not $groups -or $groups.Count -eq 0) {
        Write-Host "ℹ️  No Auto Scaling groups found in region $Region." -ForegroundColor Yellow
        return
    }

    if ($OutputFormat -eq 'JSON') {
        Write-Host $result
    } else {
        Write-Host "`n📊 Summary: $($groups.Count) Auto Scaling group(s) found" -ForegroundColor Blue
        Write-Host ("  {0,-35} {1,-6} {2,-6} {3,-6} {4,-12} {5}" -f "Name", "Min", "Des", "Max", "HealthCheck", "Status") -ForegroundColor Cyan
        Write-Host ("  {0,-35} {1,-6} {2,-6} {3,-6} {4,-12} {5}" -f "----", "---", "---", "---", "-----------", "------") -ForegroundColor Cyan
        foreach ($g in $groups) {
            $status = $g.Status
            if (-not $status) { $status = 'Active' }
            Write-Host ("  {0,-35} {1,-6} {2,-6} {3,-6} {4,-12} {5}" -f `
                $g.AutoScalingGroupName, $g.MinSize, $g.DesiredCapacity, $g.MaxSize, $g.HealthCheckType, $status)

            # Show instances per lifecycle state
            if ($g.Instances -and $g.Instances.Count -gt 0) {
                $lifeCycleSummary = $g.Instances | Group-Object LifecycleState |
                    ForEach-Object { "$($_.Name): $($_.Count)" }
                Write-Host ("    Instances: " + ($lifeCycleSummary -join ', ')) -ForegroundColor Gray
            }
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
