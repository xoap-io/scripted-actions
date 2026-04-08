<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Scaling Plan.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Scaling Plan.
    Uses the Update-AzWvdScalingPlan cmdlet from the Az.DesktopVirtualization module.

.PARAMETER Name
    The name of the scaling plan.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER Description
    The description of the scaling plan.

.PARAMETER ExclusionTag
    The exclusion tag for the scaling plan.

.PARAMETER FriendlyName
    The friendly name of the scaling plan.

.PARAMETER Tags
    A hashtable of tags to assign to the scaling plan.

.PARAMETER TimeZone
    The time zone for the scaling plan.

.EXAMPLE
    PS C:\> .\Update-AzWvdScalingPlan.ps1 -Name "MyScalingPlan" -ResourceGroup "MyResourceGroup" -Description "Updated Description"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdscalingplan?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the scaling plan to update.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false, HelpMessage = "The description of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "The exclusion tag for the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$ExclusionTag,

    [Parameter(Mandatory=$false, HelpMessage = "The friendly display name of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[IScalingHostPoolReference[]]$HostPoolReference,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[IScalingSchedule[]]$Schedule,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to assign to the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false, HelpMessage = "The time zone for the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$TimeZone
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Splatting parameters for better readability
    $parameters = @{
        Name              = $Name
        ResourceGroupName = $ResourceGroup
    }

    if ($Description) {
        $parameters['Description'] = $Description
    }

    if ($ExclusionTag) {
        $parameters['ExclusionTag'] = $ExclusionTag
    }

    if ($FriendlyName) {
        $parameters['FriendlyName'] = $FriendlyName
    }

    #if ($HostPoolReference) {
    #    $parameters['HostPoolReference'] = $HostPoolReference
    #}

    #if ($Schedule) {
    #    $parameters['Schedule'] = $Schedule
    #}

    if ($Tags) {
        $parameters['Tag'] = $Tags
    }

    if ($TimeZone) {
        $parameters['TimeZone'] = $TimeZone
    }

    # Update the Azure Virtual Desktop Scaling Plan and capture the result
    $result = Update-AzWvdScalingPlan @parameters

    # Output the result
    Write-Host "✅ Azure Virtual Desktop Scaling Plan updated successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
