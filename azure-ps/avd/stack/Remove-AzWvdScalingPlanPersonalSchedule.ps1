<#
.SYNOPSIS
    Removes a personal schedule from a scaling plan in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified personal schedule from a scaling plan in an Azure Virtual Desktop environment.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER ScalingPlanName
    The name of the scaling plan.

.PARAMETER ScalingPlanScheduleName
    The name of the scaling plan schedule.

.EXAMPLE
    PS C:\> .\Remove-AzWvdScalingPlanPersonalSchedule.ps1 -ResourceGroup "MyResourceGroup" -ScalingPlanName "MyScalingPlan" -ScalingPlanScheduleName "MySchedule"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdscalingplanpersonalschedule?view=azps-11.6.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScalingPlanName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ScalingPlanScheduleName
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroup       = $ResourceGroup
    ScalingPlanName         = $ScalingPlanName
    ScalingPlanScheduleName = $ScalingPlanScheduleName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the personal schedule from the scaling plan and capture the result
    $result = Remove-AzWvdScalingPlanPersonalSchedule @parameters

    # Output the result
    Write-Output "Personal schedule removed from scaling plan successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the personal schedule from the scaling plan: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
