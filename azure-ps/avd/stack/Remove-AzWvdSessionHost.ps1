<#
.SYNOPSIS
    Removes an Azure Virtual Desktop Session Host.

.DESCRIPTION
    This script removes a specified session host from an Azure Virtual Desktop environment.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER Name
    The name of the session host.

.PARAMETER ResourceGroupName
    The name of the resource group.

.EXAMPLE
    PS C:\> .\Remove-AzWvdSessionHost.ps1 -HostPoolName "MyHostPool" -Name "MySessionHost" -ResourceGroupName "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdsessionhost?view=azps-12.3.0

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
    [string]$ResourceGroupName
)

# Splatting parameters for better readability
$parameters = @{
    HostPoolName      = $HostPoolName
    Name              = $Name
    ResourceGroupName = $ResourceGroupName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the Azure Virtual Desktop Session Host and capture the result
    $result = Remove-AzWvdSessionHost @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Session Host removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the Azure Virtual Desktop Session Host: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
