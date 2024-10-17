<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Session Host.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Session Host.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER Name
    The name of the session host.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER AllowNewSession
    Specifies whether new sessions are allowed.

.PARAMETER AssignedUser
    The user assigned to the session host.

.PARAMETER FriendlyName
    The friendly name of the session host.

.EXAMPLE
    PS C:\> .\Update-AzWvdSessionHost.ps1 -HostPoolName "MyHostPool" -Name "MySessionHost" -ResourceGroupName "MyResourceGroup" -AllowNewSession $true

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdsessionhost?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$AllowNewSession,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AssignedUser,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName
)

# Splatting parameters for better readability
$parameters = @{
    HostPoolName       = $HostPoolName
    Name               = $Name
    ResourceGroupName  = $ResourceGroupName
}

if ($AllowNewSession) {
    $parameters['AllowNewSession', $AllowNewSession
}

if ($AssignedUser) {
    $parameters['AssignedUser', $AssignedUser
}

if ($FriendlyName) {
    $parameters['FriendlyName', $FriendlyName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Update the Azure Virtual Desktop Session Host and capture the result
    $result = Update-AzWvdSessionHost @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Session Host updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop Session Host: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
