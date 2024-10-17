<#
.SYNOPSIS
Updates an Azure Virtual Desktop Scaling Plan Pooled Schedule.

.DESCRIPTION
This script updates the properties of an Azure Virtual Desktop Scaling Plan Pooled Schedule.

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
Specifies when to stop hosts during ramp down.

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
PS C:\> .\Update-AzWvdScalingPlanPooledSchedule.ps1 -ResourceGroupName "MyResourceGroup" -ScalingPlanName "MyScalingPlan" -ScalingPlanScheduleName "MySchedule"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK


.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$ScalingPlanName,

    [Parameter(Mandatory=$true)]
    [string]$ScalingPlanScheduleName,


    [DayOfWeek[]]$DaysOfWeek = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday"),

    [SessionHostLoadBalancingAlgorithm]$OffPeakLoadBalancingAlgorithm = "BreadthFirst",

    [int]$OffPeakStartTimeHour = 0,

    [int]$OffPeakStartTimeMinute = 0,

    [SessionHostLoadBalancingAlgorithm]$PeakLoadBalancingAlgorithm = "DepthFirst",

    [int]$PeakStartTimeHour = 9,

    [int]$PeakStartTimeMinute = 0,

    [int]$RampDownCapacityThresholdPct = 20,

    [switch]$RampDownForceLogoffUser,

    [SessionHostLoadBalancingAlgorithm]$RampDownLoadBalancingAlgorithm = "DepthFirst",

    [int]$RampDownMinimumHostsPct = 10,

    [string]$RampDownNotificationMessage = "Logging off users for ramp down.",

    [int]$RampDownStartTimeHour = 18,

    [int]$RampDownStartTimeMinute = 0,

    [StopHostsWhen]$RampDownStopHostsWhen = "WhenNoSessions",

    [int]$RampDownWaitTimeMinute = 30,

    [int]$RampUpCapacityThresholdPct = 80,

    [SessionHostLoadBalancingAlgorithm]$RampUpLoadBalancingAlgorithm = "BreadthFirst",

    [int]$RampUpMinimumHostsPct = 50,

    [int]$RampUpStartTimeHour = 8,

    [int]$RampUpStartTimeMinute = 0
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName            = $ResourceGroupName
    ScalingPlanName              = $ScalingPlanName
    ScalingPlanScheduleName      = $ScalingPlanScheduleName
    DaysOfWeek                   = $DaysOfWeek
    OffPeakLoadBalancingAlgorithm = $OffPeakLoadBalancingAlgorithm
    OffPeakStartTimeHour         = $OffPeakStartTimeHour
    OffPeakStartTimeMinute       = $OffPeakStartTimeMinute
    PeakLoadBalancingAlgorithm   = $PeakLoadBalancingAlgorithm
    PeakStartTimeHour            = $PeakStartTimeHour
    PeakStartTimeMinute          = $PeakStartTimeMinute
    RampDownCapacityThresholdPct = $RampDownCapacityThresholdPct
    RampDownForceLogoffUser      = $RampDownForceLogoffUser
    RampDownLoadBalancingAlgorithm = $RampDownLoadBalancingAlgorithm
    RampDownMinimumHostsPct      = $RampDownMinimumHostsPct
    RampDownNotificationMessage  = $RampDownNotificationMessage
    RampDownStartTimeHour        = $RampDownStartTimeHour
    RampDownStartTimeMinute      = $RampDownStartTimeMinute
    RampDownStopHostsWhen        = $RampDownStopHostsWhen
    RampDownWaitTimeMinute       = $RampDownWaitTimeMinute
    RampUpCapacityThresholdPct   = $RampUpCapacityThresholdPct
    RampUpLoadBalancingAlgorithm = $RampUpLoadBalancingAlgorithm
    RampUpMinimumHostsPct        = $RampUpMinimumHostsPct
    RampUpStartTimeHour          = $RampUpStartTimeHour
    RampUpStartTimeMinute        = $RampUpStartTimeMinute
}

try {
    # Update the Azure Virtual Desktop Scaling Plan Pooled Schedule and capture the result
    $result = Update-AzWvdScalingPlanPooledSchedule @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Scaling Plan Pooled Schedule updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop Scaling Plan Pooled Schedule: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
