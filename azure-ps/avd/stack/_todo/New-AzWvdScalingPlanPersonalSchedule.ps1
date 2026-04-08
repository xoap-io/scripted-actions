<#
.SYNOPSIS
    Creates a new scaling plan personal schedule in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new scaling plan personal schedule in an Azure Virtual Desktop environment with the specified parameters.
    Uses the New-AzWvdScalingPlanPersonalSchedule cmdlet from the Az.DesktopVirtualization module.

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdscalingplanpersonalschedule?view=azps-12.3.0

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

    [Parameter(Mandatory=$false, HelpMessage = "The action on disconnect during off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [string]$OffPeakActionOnDisconnect,

    [Parameter(Mandatory=$false, HelpMessage = "The action on logoff during off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [string]$OffPeakActionOnLogoff,

    [Parameter(Mandatory=$false, HelpMessage = "The minutes to wait on disconnect during off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$OffPeakMinutesToWaitOnDisconnect,

    [Parameter(Mandatory=$false, HelpMessage = "The minutes to wait on logoff during off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$OffPeakMinutesToWaitOnLogoff,

    [Parameter(Mandatory=$false, HelpMessage = "The start time hour for off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$OffPeakStartTimeHour,

    [Parameter(Mandatory=$false, HelpMessage = "The start time minute for off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$OffPeakStartTimeMinute,

    [Parameter(Mandatory=$false, HelpMessage = "The start VM on connect setting for off-peak hours.")]
    [ValidateNotNullOrEmpty()]
    [string]$OffPeakStartVMOnConnect,

    [Parameter(Mandatory=$false, HelpMessage = "The action on disconnect during peak hours.")]
    [ValidateNotNullOrEmpty()]
    [string]$PeakActionOnDisconnect,

    [Parameter(Mandatory=$false, HelpMessage = "The action on logoff during peak hours.")]
    [ValidateNotNullOrEmpty()]
    [string]$PeakActionOnLogoff,

    [Parameter(Mandatory=$false, HelpMessage = "The minutes to wait on disconnect during peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$PeakMinutesToWaitOnDisconnect,

    [Parameter(Mandatory=$false, HelpMessage = "The minutes to wait on logoff during peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$PeakMinutesToWaitOnLogoff,

    [Parameter(Mandatory=$false, HelpMessage = "The start time hour for peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$PeakStartTimeHour,

    [Parameter(Mandatory=$false, HelpMessage = "The start time minute for peak hours.")]
    [ValidateNotNullOrEmpty()]
    [int]$PeakStartTimeMinute,

    [Parameter(Mandatory=$false, HelpMessage = "The start VM on connect setting for peak hours.")]
    [ValidateNotNullOrEmpty()]
    [string]$PeakStartVMOnConnect,

    [Parameter(Mandatory=$false, HelpMessage = "The action on disconnect during ramp down.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampDownActionOnDisconnect,

    [Parameter(Mandatory=$false, HelpMessage = "The action on logoff during ramp down.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampDownActionOnLogoff,

    [Parameter(Mandatory=$false, HelpMessage = "The minutes to wait on disconnect during ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownMinutesToWaitOnDisconnect,

    [Parameter(Mandatory=$false, HelpMessage = "The minutes to wait on logoff during ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownMinutesToWaitOnLogoff,

    [Parameter(Mandatory=$false, HelpMessage = "The start time hour for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownStartTimeHour,

    [Parameter(Mandatory=$false, HelpMessage = "The start time minute for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampDownStartTimeMinute,

    [Parameter(Mandatory=$false, HelpMessage = "The start VM on connect setting for ramp down.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampDownStartVMOnConnect,

    [Parameter(Mandatory=$false, HelpMessage = "The action on disconnect during ramp up.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampUpActionOnDisconnect,

    [Parameter(Mandatory=$false, HelpMessage = "The action on logoff during ramp up.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampUpActionOnLogoff,

    [Parameter(Mandatory=$false, HelpMessage = "The auto start host setting for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampUpAutoStartHost,

    [Parameter(Mandatory=$false, HelpMessage = "The minutes to wait on disconnect during ramp up.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampUpMinutesToWaitOnDisconnect,

    [Parameter(Mandatory=$false, HelpMessage = "The minutes to wait on logoff during ramp up.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampUpMinutesToWaitOnLogoff,

    [Parameter(Mandatory=$false, HelpMessage = "The start time hour for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampUpStartTimeHour,

    [Parameter(Mandatory=$false, HelpMessage = "The start time minute for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [int]$RampUpStartTimeMinute,

    [Parameter(Mandatory=$false, HelpMessage = "The start VM on connect setting for ramp up.")]
    [ValidateNotNullOrEmpty()]
    [string]$RampUpStartVMOnConnect
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
if ($OffPeakActionOnDisconnect) { $parameters['OffPeakActionOnDisconnect'] = $OffPeakActionOnDisconnect }
if ($OffPeakActionOnLogoff) { $parameters['OffPeakActionOnLogoff'] = $OffPeakActionOnLogoff }
if ($OffPeakMinutesToWaitOnDisconnect) { $parameters['OffPeakMinutesToWaitOnDisconnect'] = $OffPeakMinutesToWaitOnDisconnect }
if ($OffPeakMinutesToWaitOnLogoff) { $parameters['OffPeakMinutesToWaitOnLogoff'] = $OffPeakMinutesToWaitOnLogoff }
if ($OffPeakStartTimeHour) { $parameters['OffPeakStartTimeHour'] = $OffPeakStartTimeHour }
if ($OffPeakStartTimeMinute) { $parameters['OffPeakStartTimeMinute'] = $OffPeakStartTimeMinute }
if ($OffPeakStartVMOnConnect) { $parameters['OffPeakStartVMOnConnect'] = $OffPeakStartVMOnConnect }
if ($PeakActionOnDisconnect) { $parameters['PeakActionOnDisconnect'] = $PeakActionOnDisconnect }
if ($PeakActionOnLogoff) { $parameters['PeakActionOnLogoff'] = $PeakActionOnLogoff }
if ($PeakMinutesToWaitOnDisconnect) { $parameters['PeakMinutesToWaitOnDisconnect'] = $PeakMinutesToWaitOnDisconnect }
if ($PeakMinutesToWaitOnLogoff) { $parameters['PeakMinutesToWaitOnLogoff'] = $PeakMinutesToWaitOnLogoff }
if ($PeakStartTimeHour) { $parameters['PeakStartTimeHour'] = $PeakStartTimeHour }
if ($PeakStartTimeMinute) { $parameters['PeakStartTimeMinute'] = $PeakStartTimeMinute }
if ($PeakStartVMOnConnect) { $parameters['PeakStartVMOnConnect'] = $PeakStartVMOnConnect }
if ($RampDownActionOnDisconnect) { $parameters['RampDownActionOnDisconnect'] = $RampDownActionOnDisconnect }
if ($RampDownActionOnLogoff) { $parameters['RampDownActionOnLogoff'] = $RampDownActionOnLogoff }
if ($RampDownMinutesToWaitOnDisconnect) { $parameters['RampDownMinutesToWaitOnDisconnect'] = $RampDownMinutesToWaitOnDisconnect }
if ($RampDownMinutesToWaitOnLogoff) { $parameters['RampDownMinutesToWaitOnLogoff'] = $RampDownMinutesToWaitOnLogoff }
if ($RampDownStartTimeHour) { $parameters['RampDownStartTimeHour'] = $RampDownStartTimeHour }
if ($RampDownStartTimeMinute) { $parameters['RampDownStartTimeMinute'] = $RampDownStartTimeMinute }
if ($RampDownStartVMOnConnect) { $parameters['RampDownStartVMOnConnect'] = $RampDownStartVMOnConnect }
if ($RampUpActionOnDisconnect) { $parameters['RampUpActionOnDisconnect'] = $RampUpActionOnDisconnect }
if ($RampUpActionOnLogoff) { $parameters['RampUpActionOnLogoff'] = $RampUpActionOnLogoff }
if ($RampUpAutoStartHost) { $parameters['RampUpAutoStartHost'] = $RampUpAutoStartHost }
if ($RampUpMinutesToWaitOnDisconnect) { $parameters['RampUpMinutesToWaitOnDisconnect'] = $RampUpMinutesToWaitOnDisconnect }
if ($RampUpMinutesToWaitOnLogoff) { $parameters['RampUpMinutesToWaitOnLogoff'] = $RampUpMinutesToWaitOnLogoff }
if ($RampUpStartTimeHour) { $parameters['RampUpStartTimeHour'] = $RampUpStartTimeHour }
if ($RampUpStartTimeMinute) { $parameters['RampUpStartTimeMinute'] = $RampUpStartTimeMinute }
if ($RampUpStartVMOnConnect) { $parameters['RampUpStartVMOnConnect'] = $RampUpStartVMOnConnect }

try {
    # Create the scaling plan personal schedule and capture the result
    $result = New-AzWvdScalingPlanPersonalSchedule @parameters

    # Output the result
    Write-Host "✅ Scaling plan personal schedule created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
