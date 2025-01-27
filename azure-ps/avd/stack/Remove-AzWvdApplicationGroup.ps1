<#
.SYNOPSIS
    emoves an application group from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified application group from an Azure Virtual Desktop environment.

.PARAMETER Name
    The name of the application group.

.PARAMETER ResourceGroup
    The name of the resource group.

.EXAMPLE
    PS C:\> .\Remove-AzWvdApplicationGroup.ps1 -Name "MyAppGroup" -ResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdapplicationgroup?view=azps-12.2.0

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
    # Remove the application group and capture the result
    $result = Remove-AzWvdApplicationGroup @parameters

    # Output the result
    Write-Output "Application group removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the application group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
