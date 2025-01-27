<#
.SYNOPSIS
Creates a new scaling plan personal schedule in an Azure Virtual Desktop environment.

.DESCRIPTION
This script creates a new scaling plan personal schedule in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER ResourceGroup
The name of the resource group.

.PARAMETER ScalingPlanName
The name of the scaling plan.

.PARAMETER ScalingPlanScheduleName
The name of the scaling plan schedule.


.PARAMETER DaysOfWeek
The days of the week for the schedule.

.PARAMETER OffPeakActionOnDisconnect
The action on disconnect during off-peak hours.

.PARAMETER OffPeakActionOnLogoff
The action on logoff during off-peak hours.

.PARAMETER OffPeakMinutesToWaitOnDisconnect
The minutes to wait on disconnect during off-peak hours.

.PARAMETER OffPeakMinutesToWaitOnLogoff
The minutes to wait on logoff during off-peak hours.

.PARAMETER OffPeakStartTimeHour
The start time hour for off-peak hours.

.PARAMETER OffPeakStartTimeMinute
The start time minute for off-peak hours.

.PARAMETER OffPeakStartVMOnConnect
The start VM on connect setting for off-peak hours.

.PARAMETER PeakActionOnDisconnect
The action on disconnect during peak hours.

.PARAMETER PeakActionOnLogoff
The action on logoff during peak hours.

.PARAMETER PeakMinutesToWaitOnDisconnect
The minutes to wait on disconnect during peak hours.

.PARAMETER PeakMinutesToWaitOnLogoff
The minutes to wait on logoff during peak hours.

.PARAMETER PeakStartTimeHour
The start time hour for peak hours.

.PARAMETER PeakStartTimeMinute
The start time minute for peak hours.

.PARAMETER PeakStartVMOnConnect
The start VM on connect setting for peak hours.

.PARAMETER RampDownActionOnDisconnect
The action on disconnect during ramp down.

.PARAMETER RampDownActionOnLogoff
The action on logoff during ramp down.

.PARAMETER RampDownMinutesToWaitOnDisconnect
The minutes to wait on disconnect during ramp down.

.PARAMETER RampDownMinutesToWaitOnLogoff
The minutes to wait on logoff during ramp down.

.PARAMETER RampDownStartTimeHour
The start time hour for ramp down.

.PARAMETER RampDownStartTimeMinute
The start time minute for ramp down.

.PARAMETER RampDownStartVMOnConnect
The start VM on connect setting for ramp down.

.PARAMETER RampUpActionOnDisconnect
The action on disconnect during ramp up.

.PARAMETER RampUpActionOnLogoff
The action on logoff during ramp up.

.PARAMETER RampUpAutoStartHost
The auto start host setting for ramp up.

.PARAMETER RampUpMinutesToWaitOnDisconnect
The minutes to wait on disconnect during ramp up.

.PARAMETER RampUpMinutesToWaitOnLogoff
The minutes to wait on logoff during ramp up.

.PARAMETER RampUpStartTimeHour
The start time hour for ramp up.

.PARAMETER RampUpStartTimeMinute
The start time minute for ramp up.

.PARAMETER RampUpStartVMOnConnect
The start VM on connect setting for ramp up.


.EXAMPLE
PS C:\> .\New-AzWvdScalingPlanPersonalSchedule.ps1 -ResourceGroup "MyResourceGroup" -ScalingPlanName "MyScalingPlan" -ScalingPlanScheduleName "MySchedule"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [string]$ScalingPlanName,

    [Parameter(Mandatory=$true)]
    [string]$ScalingPlanScheduleName,


    [DayOfWeek[]]$DaysOfWeek,

    [SessionHandlingOperation]$OffPeakActionOnDisconnect,

    [SessionHandlingOperation]$OffPeakActionOnLogoff,

    [int]$OffPeakMinutesToWaitOnDisconnect,

    [int]$OffPeakMinutesToWaitOnLogoff,

    [int]$OffPeakStartTimeHour,

    [int]$OffPeakStartTimeMinute,

    [SetStartVMOnConnect]$OffPeakStartVMOnConnect,

    [SessionHandlingOperation]$PeakActionOnDisconnect,

    [SessionHandlingOperation]$PeakActionOnLogoff,

    [int]$PeakMinutesToWaitOnDisconnect,

    [int]$PeakMinutesToWaitOnLogoff,

    [int]$PeakStartTimeHour,

    [int]$PeakStartTimeMinute,

    [SetStartVMOnConnect]$PeakStartVMOnConnect,

    [SessionHandlingOperation]$RampDownActionOnDisconnect,

    [SessionHandlingOperation]$RampDownActionOnLogoff,

    [int]$RampDownMinutesToWaitOnDisconnect,

    [int]$RampDownMinutesToWaitOnLogoff,

    [int]$RampDownStartTimeHour,

    [int]$RampDownStartTimeMinute,

    [SetStartVMOnConnect]$RampDownStartVMOnConnect,

    [SessionHandlingOperation]$RampUpActionOnDisconnect,

    [SessionHandlingOperation]$RampUpActionOnLogoff,

    [StartupBehavior]$RampUpAutoStartHost,

    [int]$RampUpMinutesToWaitOnDisconnect,

    [int]$RampUpMinutesToWaitOnLogoff,

    [int]$RampUpStartTimeHour,

    [int]$RampUpStartTimeMinute,

    [SetStartVMOnConnect]$RampUpStartVMOnConnect



)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroup                   = $ResourceGroup
    ScalingPlanName                     = $ScalingPlanName
    ScalingPlanScheduleName             = $ScalingPlanScheduleName
    DaysOfWeek                          = $DaysOfWeek
    OffPeakActionOnDisconnect           = $OffPeakActionOnDisconnect
    OffPeakActionOnLogoff               = $OffPeakActionOnLogoff
    OffPeakMinutesToWaitOnDisconnect    = $OffPeakMinutesToWaitOnDisconnect
    OffPeakMinutesToWaitOnLogoff        = $OffPeakMinutesToWaitOnLogoff
    OffPeakStartTimeHour                = $OffPeakStartTimeHour
    OffPeakStartTimeMinute              = $OffPeakStartTimeMinute
    OffPeakStartVMOnConnect             = $OffPeakStartVMOnConnect
    PeakActionOnDisconnect              = $PeakActionOnDisconnect
    PeakActionOnLogoff                  = $PeakActionOnLogoff
    PeakMinutesToWaitOnDisconnect       = $PeakMinutesToWaitOnDisconnect
    PeakMinutesToWaitOnLogoff           = $PeakMinutesToWaitOnLogoff
    PeakStartTimeHour                   = $PeakStartTimeHour
    PeakStartTimeMinute                 = $PeakStartTimeMinute
    PeakStartVMOnConnect                = $PeakStartVMOnConnect
    RampDownActionOnDisconnect          = $RampDownActionOnDisconnect
    RampDownActionOnLogoff              = $RampDownActionOnLogoff
    RampDownMinutesToWaitOnDisconnect   = $RampDownMinutesToWaitOnDisconnect
    RampDownMinutesToWaitOnLogoff       = $RampDownMinutesToWaitOnLogoff
    RampDownStartTimeHour               = $RampDownStartTimeHour
    RampDownStartTimeMinute             = $RampDownStartTimeMinute
    RampDownStartVMOnConnect            = $RampDownStartVMOnConnect
    RampUpActionOnDisconnect            = $RampUpActionOnDisconnect
    RampUpActionOnLogoff                = $RampUpActionOnLogoff
    RampUpAutoStartHost                 = $RampUpAutoStartHost
    RampUpMinutesToWaitOnDisconnect     = $RampUpMinutesToWaitOnDisconnect
    RampUpMinutesToWaitOnLogoff         = $RampUpMinutesToWaitOnLogoff
    RampUpStartTimeHour                 = $RampUpStartTimeHour
    RampUpStartTimeMinute               = $RampUpStartTimeMinute
    RampUpStartVMOnConnect              = $RampUpStartVMOnConnect
}

try {
    # Create the scaling plan personal schedule and capture the result
    $result = New-AzWvdScalingPlanPersonalSchedule @parameters

    # Output the result
    Write-Output "Scaling plan personal schedule created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the scaling plan personal schedule: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
