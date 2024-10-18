<#
.SYNOPSIS
    Removes a scaling plan from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified scaling plan from an Azure Virtual Desktop environment.

.PARAMETER Name
    The name of the scaling plan.

.PARAMETER ResourceGroup
    The name of the resource group.

.EXAMPLE
    PS C:\> .\Remove-AzWvdScalingPlan.ps1 -Name "MyScalingPlan" -ResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdscalingplan?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup
)

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroup = $ResourceGroup
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the scaling plan and capture the result
    $result = Remove-AzWvdScalingPlan @parameters

    # Output the result
    Write-Output "Scaling plan removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the scaling plan: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
