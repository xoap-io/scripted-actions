<#
.SYNOPSIS
    Removes registration information from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes the specified registration information from an Azure Virtual Desktop environment.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER HostPoolName
    The name of the host pool.

.EXAMPLE
    PS C:\> .\Remove-AzWvdRegistrationInfo.ps1 -ResourceGroup "MyResourceGroup" -HostPoolName "MyHostPool"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdregistrationinfo?view=azps-12.3.0

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
    [string]$HostPoolName
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroup = $ResourceGroup
    HostPoolName      = $HostPoolName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the registration information and capture the result
    $result = Remove-AzWvdRegistrationInfo @parameters

    # Output the result
    Write-Output "Registration information removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the registration information: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
