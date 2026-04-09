<#
.SYNOPSIS
    Removes a personal schedule from a scaling plan in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified personal schedule from a scaling plan in an Azure Virtual Desktop environment.
    Uses the Remove-AzWvdScalingPlanPersonalSchedule cmdlet from the Az.DesktopVirtualization module.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER ScalingPlanName
    The name of the scaling plan.

.PARAMETER ScalingPlanScheduleName
    The name of the scaling plan schedule.

.EXAMPLE
    PS C:\> .\Remove-AzWvdScalingPlanPersonalSchedule.ps1 -ResourceGroup "MyResourceGroup" -ScalingPlanName "MyScalingPlan" -ScalingPlanScheduleName "MySchedule"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdscalingplanpersonalschedule?view=azps-11.6.0

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

    [Parameter(Mandatory=$true, HelpMessage = "The name of the scaling plan schedule to remove.")]
    [ValidateNotNullOrEmpty()]
    [string]$ScalingPlanScheduleName
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName       = $ResourceGroup
    ScalingPlanName         = $ScalingPlanName
    ScalingPlanScheduleName = $ScalingPlanScheduleName
}

try {
    # Remove the personal schedule from the scaling plan and capture the result
    $result = Remove-AzWvdScalingPlanPersonalSchedule @parameters

    # Output the result
    Write-Host "✅ Personal schedule removed from scaling plan successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
