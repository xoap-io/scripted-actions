<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Session Host.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Session Host.
    Uses the Update-AzWvdSessionHost cmdlet from the Az.DesktopVirtualization module.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER Name
    The name of the session host.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER AllowNewSession
    Specifies whether new sessions are allowed.

.PARAMETER AssignedUser
    The user assigned to the session host.

.PARAMETER FriendlyName
    The friendly name of the session host.

.EXAMPLE
    PS C:\> .\Update-AzWvdSessionHost.ps1 -HostPoolName "MyHostPool" -Name "MySessionHost" -ResourceGroup "MyResourceGroup" -AllowNewSession $true

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdsessionhost?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the session host to update.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false, HelpMessage = "Specifies whether new sessions are allowed on the session host.")]
    [ValidateNotNullOrEmpty()]
    [bool]$AllowNewSession,

    [Parameter(Mandatory=$false, HelpMessage = "The user assigned to the session host.")]
    [ValidateNotNullOrEmpty()]
    [string]$AssignedUser,

    [Parameter(Mandatory=$false, HelpMessage = "The friendly display name of the session host.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    HostPoolName      = $HostPoolName
    Name              = $Name
    ResourceGroupName = $ResourceGroup
}

if ($AllowNewSession) {
    $parameters['AllowNewSession'] = $AllowNewSession
}

if ($AssignedUser) {
    $parameters['AssignedUser'] = $AssignedUser
}

if ($FriendlyName) {
    $parameters['FriendlyName'] = $FriendlyName
}

try {
    # Update the Azure Virtual Desktop Session Host and capture the result
    $result = Update-AzWvdSessionHost @parameters

    # Output the result
    Write-Host "✅ Azure Virtual Desktop Session Host updated successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
