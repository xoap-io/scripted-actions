<#
.SYNOPSIS
    Removes a scaling plan from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified scaling plan from an Azure Virtual Desktop environment.
    Uses the Remove-AzWvdScalingPlan cmdlet from the Az.DesktopVirtualization module.

.PARAMETER Name
    The name of the scaling plan.

.PARAMETER ResourceGroup
    The name of the resource group.

.EXAMPLE
    PS C:\> .\Remove-AzWvdScalingPlan.ps1 -Name "MyScalingPlan" -ResourceGroup "MyResourceGroup"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdscalingplan?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the scaling plan to remove.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroup
}

try {
    # Remove the scaling plan and capture the result
    $result = Remove-AzWvdScalingPlan @parameters

    # Output the result
    Write-Host "✅ Scaling plan removed successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
