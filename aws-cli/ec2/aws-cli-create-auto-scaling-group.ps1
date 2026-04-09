<#
.SYNOPSIS
    Create an EC2 Auto Scaling group using the AWS CLI.

.DESCRIPTION
    Creates an Amazon EC2 Auto Scaling group with the specified launch template,
    capacity settings, VPC subnets, and health check configuration.
    Uses the AWS CLI command: aws autoscaling create-auto-scaling-group.

.PARAMETER Region
    The AWS region in which to create the Auto Scaling group.

.PARAMETER AutoScalingGroupName
    The name of the Auto Scaling group.

.PARAMETER LaunchTemplateId
    The ID of the launch template to use. Provide either LaunchTemplateId or LaunchTemplateName.

.PARAMETER LaunchTemplateName
    The name of the launch template to use. Provide either LaunchTemplateId or LaunchTemplateName.

.PARAMETER MinSize
    The minimum number of instances in the group.

.PARAMETER MaxSize
    The maximum number of instances in the group.

.PARAMETER DesiredCapacity
    The desired number of instances in the group at launch.

.PARAMETER VpcZoneIdentifier
    Comma-separated list of subnet IDs for the Auto Scaling group.

.PARAMETER HealthCheckType
    The health check type: EC2 or ELB. Default is EC2.

.PARAMETER HealthCheckGracePeriod
    Grace period in seconds before health checks begin. Default is 300.

.EXAMPLE
    .\aws-cli-create-auto-scaling-group.ps1 -Region "us-east-1" -AutoScalingGroupName "my-asg" -LaunchTemplateId "lt-0123456789abcdef0" -MinSize 1 -MaxSize 5 -DesiredCapacity 2 -VpcZoneIdentifier "subnet-0a1b2c3d,subnet-0e4f5a6b"

.EXAMPLE
    .\aws-cli-create-auto-scaling-group.ps1 -Region "eu-west-1" -AutoScalingGroupName "web-asg" -LaunchTemplateName "web-lt" -MinSize 2 -MaxSize 10 -DesiredCapacity 4 -VpcZoneIdentifier "subnet-abc123,subnet-def456" -HealthCheckType ELB -HealthCheckGracePeriod 600

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
    https://docs.aws.amazon.com/cli/latest/reference/autoscaling/create-auto-scaling-group.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region in which to create the Auto Scaling group.")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Auto Scaling group.")]
    [ValidateNotNullOrEmpty()]
    [string]$AutoScalingGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the launch template to use.")]
    [string]$LaunchTemplateId,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the launch template to use.")]
    [string]$LaunchTemplateName,

    [Parameter(Mandatory = $true, HelpMessage = "The minimum number of instances in the group.")]
    [ValidateRange(0, 1000)]
    [int]$MinSize,

    [Parameter(Mandatory = $true, HelpMessage = "The maximum number of instances in the group.")]
    [ValidateRange(1, 1000)]
    [int]$MaxSize,

    [Parameter(Mandatory = $true, HelpMessage = "The desired number of instances in the group at launch.")]
    [ValidateRange(0, 1000)]
    [int]$DesiredCapacity,

    [Parameter(Mandatory = $true, HelpMessage = "Comma-separated list of subnet IDs for the Auto Scaling group.")]
    [ValidateNotNullOrEmpty()]
    [string]$VpcZoneIdentifier,

    [Parameter(Mandatory = $false, HelpMessage = "Health check type: EC2 or ELB. Default is EC2.")]
    [ValidateSet('EC2', 'ELB')]
    [string]$HealthCheckType = 'EC2',

    [Parameter(Mandatory = $false, HelpMessage = "Grace period in seconds before health checks begin (0-86400). Default is 300.")]
    [ValidateRange(0, 86400)]
    [int]$HealthCheckGracePeriod = 300
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

# Validate launch template source
if (-not $LaunchTemplateId -and -not $LaunchTemplateName) {
    Write-Host "❌ Provide either LaunchTemplateId or LaunchTemplateName." -ForegroundColor Red
    exit 1
}

# Validate capacity ordering
if ($DesiredCapacity -lt $MinSize -or $DesiredCapacity -gt $MaxSize) {
    Write-Host "❌ DesiredCapacity ($DesiredCapacity) must be between MinSize ($MinSize) and MaxSize ($MaxSize)." -ForegroundColor Red
    exit 1
}

try {
    Write-Host "🚀 Starting Auto Scaling Group Creation" -ForegroundColor Green
    Write-Host "🔍 Validating AWS CLI configuration..." -ForegroundColor Cyan
    aws sts get-caller-identity --region $Region --output json 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "AWS CLI authentication failed. Run 'aws configure'." }
    Write-Host "✅ AWS CLI authenticated." -ForegroundColor Green

    # Build launch template specification
    if ($LaunchTemplateId) {
        $ltSpec = "LaunchTemplateId=$LaunchTemplateId,Version=`$Default"
    } else {
        $ltSpec = "LaunchTemplateName=$LaunchTemplateName,Version=`$Default"
    }

    Write-Host "🔧 Creating Auto Scaling group '$AutoScalingGroupName'..." -ForegroundColor Cyan

    $result = aws autoscaling create-auto-scaling-group `
        --region $Region `
        --auto-scaling-group-name $AutoScalingGroupName `
        --launch-template "$ltSpec" `
        --min-size $MinSize `
        --max-size $MaxSize `
        --desired-capacity $DesiredCapacity `
        --vpc-zone-identifier $VpcZoneIdentifier `
        --health-check-type $HealthCheckType `
        --health-check-grace-period $HealthCheckGracePeriod `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create Auto Scaling group: $result"
    }

    Write-Host "✅ Auto Scaling group '$AutoScalingGroupName' created successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Group name:           $AutoScalingGroupName" -ForegroundColor Cyan
    Write-Host "  Region:               $Region" -ForegroundColor Cyan
    Write-Host "  Min / Desired / Max:  $MinSize / $DesiredCapacity / $MaxSize" -ForegroundColor Cyan
    Write-Host "  Health check type:    $HealthCheckType (grace: ${HealthCheckGracePeriod}s)" -ForegroundColor Cyan
    Write-Host "  Subnets:              $VpcZoneIdentifier" -ForegroundColor Cyan

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - Attach a load balancer target group with aws autoscaling attach-load-balancer-target-groups." -ForegroundColor Yellow
    Write-Host "  - Configure scaling policies with aws autoscaling put-scaling-policy." -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
