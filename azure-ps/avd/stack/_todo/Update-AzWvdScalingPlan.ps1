<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Scaling Plan.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Scaling Plan.

.PARAMETER Name
    The name of the scaling plan.

.PARAMETER ResourceGroupName
    The name of the resource group.


.PARAMETER Description
    The description of the scaling plan.

.PARAMETER ExclusionTag
    The exclusion tag for the scaling plan.

.PARAMETER FriendlyName
    The friendly name of the scaling plan.

.PARAMETER HostPoolReference
    References to host pools.

.PARAMETER Schedule
    The schedule for the scaling plan.

.PARAMETER Tag
    A hashtable of tags to assign to the scaling plan.

.PARAMETER TimeZone
    The time zone for the scaling plan.

.EXAMPLE
    PS C:\> .\Update-AzWvdScalingPlan.ps1 -Name "MyScalingPlan" -ResourceGroupName "MyResourceGroup" -Description "Updated Description"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdscalingplan?view=azps-12.3.0&viewFallbackFrom=azps-12.0.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name = "MyScalingPlan",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "MyResourceGroup",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description = "Default Description",
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ExclusionTag = "Default Exclusion Tag",
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName = "Default Friendly Name",
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [IScalingHostPoolReference[]]$HostPoolReference,
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [IScalingSchedule[]]$Schedule,
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,
    
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$TimeZone = "UTC"
)

try {
    # Splatting parameters for better readability
    $parameters = @{
        Name                = $Name
        ResourceGroupName   = $ResourceGroupName
    }

    if ($Description) {
        $parameters['Description', $Description
    }

    if ($ExclusionTag) {
        $parameters['ExclusionTag', $ExclusionTag
    }

    if ($FriendlyName) {
        $parameters['FriendlyName', $FriendlyName
    }

    if ($HostPoolReference) {
        $parameters['HostPoolReference', $HostPoolReference
    }

    if ($Schedule) {
        $parameters['Schedule', $Schedule
    }

    if ($Tags) {
        $parameters['Tag', $Tags
    }

    if ($TimeZone) {
        $parameters['TimeZone', $TimeZone
    }

    # Update the Azure Virtual Desktop Scaling Plan and capture the result
    $result = Update-AzWvdScalingPlan @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Scaling Plan updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop Scaling Plan: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
