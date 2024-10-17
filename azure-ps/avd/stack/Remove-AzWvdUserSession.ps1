<#
.SYNOPSIS
    Removes a user session from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified user session from an Azure Virtual Desktop environment.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER Id
    The ID of the user session.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER SessionHostName
    The name of the session host.

.EXAMPLE
    PS C:\> .\Remove-AzWvdUserSession.ps1 -HostPoolName "MyHostPool" -Id "12345" -ResourceGroupName "MyResourceGroup" -SessionHostName "MySessionHost"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdusersession?view=azps-12.3.0

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
    [string]$Id,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SessionHostName
)

# Splatting parameters for better readability
$parameters = @{
    HostPoolName      = $HostPoolName
    Id                = $Id
    ResourceGroupName = $ResourceGroupName
    SessionHostName   = $SessionHostName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the user session and capture the result
    $result = Remove-AzWvdUserSession @parameters

    # Output the result
    Write-Output "User session removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the user session: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
