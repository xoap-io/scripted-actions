<#
.SYNOPSIS
    Removes a host pool from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified host pool from an Azure Virtual Desktop environment.

.PARAMETER Name
    The name of the host pool.

.PARAMETER ResourceGroup
    The name of the resource group.

.EXAMPLE
    PS C:\> .\Remove-AzWvdHostPool.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdhostpool?view=azps-12.2.0

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
    # Remove the host pool and capture the result
    $result = Remove-AzWvdHostPool @parameters

    # Output the result
    Write-Output "Host pool removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the host pool: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
