<#
.SYNOPSIS
    Removes an MSIX package from an Azure Virtual Desktop environment.

.DESCRIPTION
    This script removes a specified MSIX package from an Azure Virtual Desktop environment.

.PARAMETER FullName
    The full name of the MSIX package.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER ResourceGroup
    The name of the resource group.

.EXAMPLE
    PS C:\> .\Remove-AzWvdMsixPackage.ps1 -FullName "MyMsixPackage" -HostPoolName "MyHostPool" -ResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/remove-azwvdmsixpackage?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$FullName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup
)

# Splatting parameters for better readability
$parameters = @{
    FullName           = $FullName
    HostPoolName       = $HostPoolName
    ResourceGroup  = $ResourceGroup
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the MSIX package and capture the result
    $result = Remove-AzWvdMsixPackage @parameters

    # Output the result
    Write-Output "MSIX package removed successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to remove the MSIX package: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
