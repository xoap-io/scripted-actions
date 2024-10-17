<#
.SYNOPSIS
    Removes a scaling plan pooled schedule from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified scaling plan pooled schedule from an Azure Virtual Desktop environment.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER ScalingPlanName
    The name of the scaling plan.

.PARAMETER ScalingPlanScheduleName
    The name of the scaling plan schedule.

.EXAMPLE
    PS C:\> .\Remove-AzWvdScalingPlanPooledSchedule.ps1 -ResourceGroupName "MyResourceGroup" -ScalingPlanName "MyScalingPlan" -ScalingPlanScheduleName "MySchedule"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdscalingplanpooledschedule?view=azps-12.2.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScalingPlanName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScalingPlanScheduleName
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName       = $ResourceGroupName
    ScalingPlanName         = $ScalingPlanName
    ScalingPlanScheduleName = $ScalingPlanScheduleName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the scaling plan pooled schedule and capture the result
    $result = Remove-AzWvdScalingPlanPooledSchedule @parameters

    # Output the result
    Write-Output "Scaling plan pooled schedule removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the scaling plan pooled schedule: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
