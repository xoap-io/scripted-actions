<#
.SYNOPSIS
    Removes an application from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified application from an Azure Virtual Desktop environment.

.PARAMETER GroupName
    The name of the application group.

.PARAMETER Name
    The name of the application.

.PARAMETER ResourceGroup
    The name of the resource group.

.EXAMPLE
    PS C:\> .\Remove-AzWvdApplication.ps1 -GroupName "MyAppGroup" -Name "MyApp" -ResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdapplication?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup
)

# Splatting parameters for better readability
$parameters = @{
    GroupName         = $GroupName
    Name              = $Name
    ResourceGroup = $ResourceGroup
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the application and capture the result
    $result = Remove-AzWvdApplication @parameters

    # Output the result
    Write-Output "Application removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the application: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
