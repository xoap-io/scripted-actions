<#
.SYNOPSIS
    Creates a new scaling plan pooled schedule in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new scaling plan pooled schedule in an Azure Virtual Desktop environment with the specified parameters.
    Uses the New-AzWvdScalingPlanPooledSchedule cmdlet from the Az.DesktopVirtualization module.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER ScalingPlanName
    The name of the scaling plan.

.PARAMETER ScalingPlanScheduleName
    The name of the scaling plan schedule.

.PARAMETER DaysOfWeek
    The days of the week for the schedule.

.PARAMETER OffPeakLoadBalancingAlgorithm
    The load balancing algorithm for off-peak hours.

.PARAMETER OffPeakStartTimeHour
    The start time hour for off-peak hours.

.PARAMETER OffPeakStartTimeMinute
    The start time minute for off-peak hours.

.PARAMETER PeakLoadBalancingAlgorithm
    The load balancing algorithm for peak hours.

.PARAMETER PeakStartTimeHour
    The start time hour for peak hours.

.PARAMETER PeakStartTimeMinute
    The start time minute for peak hours.

.PARAMETER RampDownCapacityThresholdPct
    The capacity threshold percentage for ramp down.

.PARAMETER RampDownForceLogoffUser
    Forces logoff of users during ramp down.

.PARAMETER RampDownLoadBalancingAlgorithm
    The load balancing algorithm for ramp down.

.PARAMETER RampDownMinimumHostsPct
    The minimum hosts percentage for ramp down.

.PARAMETER RampDownNotificationMessage
    The notification message for ramp down.

.PARAMETER RampDownStartTimeHour
    The start time hour for ramp down.

.PARAMETER RampDownStartTimeMinute
    The start time minute for ramp down.

.PARAMETER RampDownStopHostsWhen
    The condition to stop hosts during ramp down.

.PARAMETER RampDownWaitTimeMinute
    The wait time in minutes for ramp down.

.PARAMETER RampUpCapacityThresholdPct
    The capacity threshold percentage for ramp up.

.PARAMETER RampUpLoadBalancingAlgorithm
    The load balancing algorithm for ramp up.

.PARAMETER RampUpMinimumHostsPct
    The minimum hosts percentage for ramp up.

.PARAMETER RampUpStartTimeHour
    The start time hour for ramp up.

.PARAMETER RampUpStartTimeMinute
    The start time minute for ramp up.

.EXAMPLE
    PS C:\> .\New-AzWvdScalingPlanPooledSchedule.ps1 -ResourceGroup "MyResourceGroup" -ScalingPlanName "MyScalingPlan" -ScalingPlanScheduleName "MySchedule"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdscalingplanpooledschedule?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$ScalingPlanName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the scaling plan schedule.")]
    [ValidateNotNullOrEmpty()]
    [string]$ScalingPlanScheduleName,

    [Parameter(Mandatory=$false, HelpMessage = "The days of the week for the schedule.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$DaysOfWeek,

    [Parameter(Mandatory=$false, HelpMessage = "The load balancing algorithm for off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [string]$OffPeakLoadBalancingAlgorithm,

    [Parameter(Mandatory=$false, HelpMessage = "The start time hour for off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$OffPeakStartTimeHour,

    [Parameter(Mandatory=$false, HelpMessage = "The start time minute for off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$OffPeakStartTimeMinute,

    [Parameter(Mandatory=$false, HelpMessage = "The load balancing algorithm for peak hours.")]
    [ValidateNotNullOrEmpty()]
    [string]$PeakLoadBalancingAlgorithm,

    [Parameter(Mandatory=$false, HelpMessage = "The start time hour for peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$PeakStartTimeHour,

    [Parameter(Mandatory=$false, HelpMessage = "The start time minute for peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$PeakStartTimeMinute,

    [Parameter(Mandatory=$false, HelpMessage = "The capacity threshold percentage for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownCapacityThresholdPct,

    [Parameter(Mandatory=$false, HelpMessage = "Forces logoff of users during ramp down.")]
    [ValidateNotNullOrEmpty()]
    [switch]$RampDownForceLogoffUser,

    [Parameter(Mandatory=$false, HelpMessage = "The load balancing algorithm for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampDownLoadBalancingAlgorithm,

    [Parameter(Mandatory=$false, HelpMessage = "The minimum hosts percentage for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownMinimumHostsPct,

    [Parameter(Mandatory=$false, HelpMessage = "The notification message sent to users during ramp down.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampDownNotificationMessage,

    [Parameter(Mandatory=$false, HelpMessage = "The start time hour for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownStartTimeHour,

    [Parameter(Mandatory=$false, HelpMessage = "The start time minute for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownStartTimeMinute,

    [Parameter(Mandatory=$false, HelpMessage = "The condition to stop hosts during ramp down.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampDownStopHostsWhen,

    [Parameter(Mandatory=$false, HelpMessage = "The wait time in minutes for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownWaitTimeMinute,

    [Parameter(Mandatory=$false, HelpMessage = "The capacity threshold percentage for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampUpCapacityThresholdPct,

    [Parameter(Mandatory=$false, HelpMessage = "The load balancing algorithm for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampUpLoadBalancingAlgorithm,

    [Parameter(Mandatory=$false, HelpMessage = "The minimum hosts percentage for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampUpMinimumHostsPct,

    [Parameter(Mandatory=$false, HelpMessage = "The start time hour for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampUpStartTimeHour,

    [Parameter(Mandatory=$false, HelpMessage = "The start time minute for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampUpStartTimeMinute
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName       = $ResourceGroup
    ScalingPlanName         = $ScalingPlanName
    ScalingPlanScheduleName = $ScalingPlanScheduleName
}

if ($DaysOfWeek) { $parameters['DaysOfWeek'] = $DaysOfWeek }
if ($OffPeakLoadBalancingAlgorithm) { $parameters['OffPeakLoadBalancingAlgorithm'] = $OffPeakLoadBalancingAlgorithm }
if ($OffPeakStartTimeHour) { $parameters['OffPeakStartTimeHour'] = $OffPeakStartTimeHour }
if ($OffPeakStartTimeMinute) { $parameters['OffPeakStartTimeMinute'] = $OffPeakStartTimeMinute }
if ($PeakLoadBalancingAlgorithm) { $parameters['PeakLoadBalancingAlgorithm'] = $PeakLoadBalancingAlgorithm }
if ($PeakStartTimeHour) { $parameters['PeakStartTimeHour'] = $PeakStartTimeHour }
if ($PeakStartTimeMinute) { $parameters['PeakStartTimeMinute'] = $PeakStartTimeMinute }
if ($RampDownCapacityThresholdPct) { $parameters['RampDownCapacityThresholdPct'] = $RampDownCapacityThresholdPct }
if ($RampDownForceLogoffUser) { $parameters['RampDownForceLogoffUser'] = $RampDownForceLogoffUser }
if ($RampDownLoadBalancingAlgorithm) { $parameters['RampDownLoadBalancingAlgorithm'] = $RampDownLoadBalancingAlgorithm }
if ($RampDownMinimumHostsPct) { $parameters['RampDownMinimumHostsPct'] = $RampDownMinimumHostsPct }
if ($RampDownNotificationMessage) { $parameters['RampDownNotificationMessage'] = $RampDownNotificationMessage }
if ($RampDownStartTimeHour) { $parameters['RampDownStartTimeHour'] = $RampDownStartTimeHour }
if ($RampDownStartTimeMinute) { $parameters['RampDownStartTimeMinute'] = $RampDownStartTimeMinute }
if ($RampDownStopHostsWhen) { $parameters['RampDownStopHostsWhen'] = $RampDownStopHostsWhen }
if ($RampDownWaitTimeMinute) { $parameters['RampDownWaitTimeMinute'] = $RampDownWaitTimeMinute }
if ($RampUpCapacityThresholdPct) { $parameters['RampUpCapacityThresholdPct'] = $RampUpCapacityThresholdPct }
if ($RampUpLoadBalancingAlgorithm) { $parameters['RampUpLoadBalancingAlgorithm'] = $RampUpLoadBalancingAlgorithm }
if ($RampUpMinimumHostsPct) { $parameters['RampUpMinimumHostsPct'] = $RampUpMinimumHostsPct }
if ($RampUpStartTimeHour) { $parameters['RampUpStartTimeHour'] = $RampUpStartTimeHour }
if ($RampUpStartTimeMinute) { $parameters['RampUpStartTimeMinute'] = $RampUpStartTimeMinute }

try {
    # Create the scaling plan pooled schedule and capture the result
    $result = New-AzWvdScalingPlanPooledSchedule @parameters

    # Output the result
    Write-Host "✅ Scaling plan pooled schedule created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
