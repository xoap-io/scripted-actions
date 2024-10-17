<#
.SYNOPSIS
Creates a new scaling plan pooled schedule in an Azure Virtual Desktop environment.

.DESCRIPTION
This script creates a new scaling plan pooled schedule in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER ResourceGroupName
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
PS C:\> .\New-AzWvdScalingPlanPooledSchedule.ps1 -ResourceGroupName "MyResourceGroup" -ScalingPlanName "MyScalingPlan" -ScalingPlanScheduleName "MySchedule"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$ScalingPlanName,

    [Parameter(Mandatory=$true)]
    [string]$ScalingPlanScheduleName,


    [DayOfWeek[]]$DaysOfWeek,

    [SessionHostLoadBalancingAlgorithm]$OffPeakLoadBalancingAlgorithm,

    [int]$OffPeakStartTimeHour,

    [int]$OffPeakStartTimeMinute,

    [SessionHostLoadBalancingAlgorithm]$PeakLoadBalancingAlgorithm,

    [int]$PeakStartTimeHour,

    [int]$PeakStartTimeMinute,

    [int]$RampDownCapacityThresholdPct,

    [switch]$RampDownForceLogoffUser,

    [SessionHostLoadBalancingAlgorithm]$RampDownLoadBalancingAlgorithm,

    [int]$RampDownMinimumHostsPct,

    [string]$RampDownNotificationMessage,

    [int]$RampDownStartTimeHour,

    [int]$RampDownStartTimeMinute,

    [StopHostsWhen]$RampDownStopHostsWhen,

    [int]$RampDownWaitTimeMinute,

    [int]$RampUpCapacityThresholdPct,

    [SessionHostLoadBalancingAlgorithm]$RampUpLoadBalancingAlgorithm,

    [int]$RampUpMinimumHostsPct,

    [int]$RampUpStartTimeHour,

    [int]$RampUpStartTimeMinute
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName               = $ResourceGroupName
    ScalingPlanName                 = $ScalingPlanName
    ScalingPlanScheduleName         = $ScalingPlanScheduleName
    DaysOfWeek                      = $DaysOfWeek
    OffPeakLoadBalancingAlgorithm   = $OffPeakLoadBalancingAlgorithm
    OffPeakStartTimeHour            = $OffPeakStartTimeHour
    OffPeakStartTimeMinute          = $OffPeakStartTimeMinute
    PeakLoadBalancingAlgorithm      = $PeakLoadBalancingAlgorithm
    PeakStartTimeHour               = $PeakStartTimeHour
    PeakStartTimeMinute             = $PeakStartTimeMinute
    RampDownCapacityThresholdPct    = $RampDownCapacityThresholdPct
    RampDownForceLogoffUser         = $RampDownForceLogoffUser
    RampDownLoadBalancingAlgorithm  = $RampDownLoadBalancingAlgorithm
    RampDownMinimumHostsPct         = $RampDownMinimumHostsPct
    RampDownNotificationMessage     = $RampDownNotificationMessage
    RampDownStartTimeHour           = $RampDownStartTimeHour
    RampDownStartTimeMinute         = $RampDownStartTimeMinute
    RampDownStopHostsWhen           = $RampDownStopHostsWhen
    RampDownWaitTimeMinute          = $RampDownWaitTimeMinute
    RampUpCapacityThresholdPct      = $RampUpCapacityThresholdPct
    RampUpLoadBalancingAlgorithm    = $RampUpLoadBalancingAlgorithm
    RampUpMinimumHostsPct           = $RampUpMinimumHostsPct
    RampUpStartTimeHour             = $RampUpStartTimeHour
    RampUpStartTimeMinute           = $RampUpStartTimeMinute
}

try {
    # Create the scaling plan pooled schedule and capture the result
    $result = New-AzWvdScalingPlanPooledSchedule @parameters

    # Output the result
    Write-Output "Scaling plan pooled schedule created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the scaling plan pooled schedule: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
