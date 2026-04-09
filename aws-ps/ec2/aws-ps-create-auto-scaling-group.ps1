<#
.SYNOPSIS
    Creates an EC2 Auto Scaling group using AWS.Tools.AutoScaling.

.DESCRIPTION
    This script creates an EC2 Auto Scaling group using the New-ASAutoScalingGroup
    cmdlet from AWS.Tools.AutoScaling. You can specify either a launch template ID
    or name to define the instance configuration. Tags provided via -Tags are
    propagated to all instances launched in the group.

.PARAMETER Region
    The AWS region to create the Auto Scaling group in (e.g. eu-central-1).

.PARAMETER AutoScalingGroupName
    The name for the new Auto Scaling group.

.PARAMETER LaunchTemplateId
    Optional ID of the EC2 launch template to use (e.g. lt-12345678abcdef01).
    Either LaunchTemplateId or LaunchTemplateName must be provided.

.PARAMETER LaunchTemplateName
    Optional name of the EC2 launch template to use.
    Either LaunchTemplateId or LaunchTemplateName must be provided.

.PARAMETER MinSize
    The minimum number of instances in the Auto Scaling group (0-1000).

.PARAMETER MaxSize
    The maximum number of instances in the Auto Scaling group (1-1000).

.PARAMETER DesiredCapacity
    The desired number of instances in the Auto Scaling group (0-1000).

.PARAMETER VpcZoneIdentifier
    Comma-separated list of subnet IDs for the Auto Scaling group
    (e.g. "subnet-12345678,subnet-abcdef12").

.PARAMETER HealthCheckType
    The type of health check to perform: EC2 (default) or ELB.

.PARAMETER HealthCheckGracePeriod
    Time in seconds after a new instance launches before health checks begin
    (0-86400, default 300).

.PARAMETER Tags
    Optional comma-separated key=value pairs to tag instances
    (e.g. "Environment=Production,Project=WebApp").

.EXAMPLE
    .\aws-ps-create-auto-scaling-group.ps1 -Region eu-central-1 -AutoScalingGroupName "WebApp-ASG" -LaunchTemplateName "WebServer-LT" -MinSize 1 -MaxSize 5 -DesiredCapacity 2 -VpcZoneIdentifier "subnet-12345678,subnet-abcdef12"
    Creates an Auto Scaling group using a named launch template.

.EXAMPLE
    .\aws-ps-create-auto-scaling-group.ps1 -Region us-east-1 -AutoScalingGroupName "API-ASG" -LaunchTemplateId lt-0abcdef1234567890 -MinSize 2 -MaxSize 10 -DesiredCapacity 4 -VpcZoneIdentifier "subnet-11111111,subnet-22222222" -HealthCheckType ELB -HealthCheckGracePeriod 120 -Tags "Environment=Production,Project=API"
    Creates an Auto Scaling group with ELB health checks and resource tags.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.AutoScaling

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/items/New-ASAutoScalingGroup.html

.COMPONENT
    AWS PowerShell AutoScaling
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AWS region to create the Auto Scaling group in (e.g. eu-central-1).")]
    [ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]
    [string]$Region,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new Auto Scaling group.")]
    [ValidateNotNullOrEmpty()]
    [string]$AutoScalingGroupName,

    [Parameter(HelpMessage = "The ID of the EC2 launch template to use (e.g. lt-12345678abcdef01).")]
    [ValidatePattern('^lt-[a-zA-Z0-9]{8,}$')]
    [string]$LaunchTemplateId,

    [Parameter(HelpMessage = "The name of the EC2 launch template to use.")]
    [string]$LaunchTemplateName,

    [Parameter(Mandatory = $true, HelpMessage = "The minimum number of instances in the Auto Scaling group (0-1000).")]
    [ValidateRange(0, 1000)]
    [int]$MinSize,

    [Parameter(Mandatory = $true, HelpMessage = "The maximum number of instances in the Auto Scaling group (1-1000).")]
    [ValidateRange(1, 1000)]
    [int]$MaxSize,

    [Parameter(Mandatory = $true, HelpMessage = "The desired number of instances in the Auto Scaling group (0-1000).")]
    [ValidateRange(0, 1000)]
    [int]$DesiredCapacity,

    [Parameter(Mandatory = $true, HelpMessage = "Comma-separated list of subnet IDs for the Auto Scaling group (e.g. 'subnet-12345678,subnet-abcdef12').")]
    [ValidateNotNullOrEmpty()]
    [string]$VpcZoneIdentifier,

    [Parameter(HelpMessage = "The type of health check to perform: EC2 (default) or ELB.")]
    [ValidateSet('EC2', 'ELB')]
    [string]$HealthCheckType = 'EC2',

    [Parameter(HelpMessage = "Seconds after instance launch before health checks begin (0-86400, default 300).")]
    [ValidateRange(0, 86400)]
    [int]$HealthCheckGracePeriod = 300,

    [Parameter(HelpMessage = "Comma-separated key=value tag pairs to apply to instances (e.g. 'Environment=Production,Project=WebApp').")]
    [string]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting Auto Scaling group creation" -ForegroundColor Green

    if (-not $LaunchTemplateId -and -not $LaunchTemplateName) {
        throw "Either -LaunchTemplateId or -LaunchTemplateName must be provided."
    }
    if ($DesiredCapacity -lt $MinSize -or $DesiredCapacity -gt $MaxSize) {
        throw "DesiredCapacity ($DesiredCapacity) must be between MinSize ($MinSize) and MaxSize ($MaxSize)."
    }

    Write-Host "🔍 Importing AWS.Tools.AutoScaling module..." -ForegroundColor Cyan
    Import-Module AWS.Tools.AutoScaling -ErrorAction Stop

    # Build launch template specification
    $ltSpec = [Amazon.AutoScaling.Model.LaunchTemplateSpecification]::new()
    if ($LaunchTemplateId) {
        $ltSpec.LaunchTemplateId = $LaunchTemplateId
        Write-Host "   LaunchTemplateId: $LaunchTemplateId" -ForegroundColor Gray
    }
    else {
        $ltSpec.LaunchTemplateName = $LaunchTemplateName
        Write-Host "   LaunchTemplateName: $LaunchTemplateName" -ForegroundColor Gray
    }
    $ltSpec.Version = '$Default'

    # Build tag list
    $asgTags = [System.Collections.Generic.List[Amazon.AutoScaling.Model.Tag]]::new()
    if ($Tags) {
        foreach ($pair in ($Tags -split ',')) {
            $pair = $pair.Trim()
            if ($pair -match '^(.+)=(.+)$') {
                $tag = [Amazon.AutoScaling.Model.Tag]::new()
                $tag.Key               = $Matches[1].Trim()
                $tag.Value             = $Matches[2].Trim()
                $tag.ResourceId        = $AutoScalingGroupName
                $tag.ResourceType      = 'auto-scaling-group'
                $tag.PropagateAtLaunch = $true
                $asgTags.Add($tag)
                Write-Host "   Tag: $($tag.Key) = $($tag.Value)" -ForegroundColor Gray
            }
        }
    }

    Write-Host "🔧 Creating Auto Scaling group '$AutoScalingGroupName'..." -ForegroundColor Cyan
    $createParams = @{
        AutoScalingGroupName = $AutoScalingGroupName
        LaunchTemplate       = $ltSpec
        MinSize              = $MinSize
        MaxSize              = $MaxSize
        DesiredCapacity      = $DesiredCapacity
        VPCZoneIdentifier    = $VpcZoneIdentifier
        HealthCheckType      = $HealthCheckType
        HealthCheckGracePeriod = $HealthCheckGracePeriod
        Region               = $Region
    }
    if ($asgTags.Count -gt 0) {
        $createParams['Tag'] = $asgTags
    }

    New-ASAutoScalingGroup @createParams | Out-Null

    Write-Host "✅ Auto Scaling group created successfully." -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   AutoScalingGroupName: $AutoScalingGroupName" -ForegroundColor White
    Write-Host "   MinSize:              $MinSize" -ForegroundColor White
    Write-Host "   MaxSize:              $MaxSize" -ForegroundColor White
    Write-Host "   DesiredCapacity:      $DesiredCapacity" -ForegroundColor White
    Write-Host "   HealthCheckType:      $HealthCheckType" -ForegroundColor White
    Write-Host "   Region:               $Region" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
