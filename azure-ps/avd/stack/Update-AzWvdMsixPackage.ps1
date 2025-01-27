<#
.SYNOPSIS
    Updates an Azure Virtual Desktop MSIX Package.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop MSIX Package.

.PARAMETER FullName
    The full name of the MSIX package.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER DisplayName
    The display name of the MSIX package.

.PARAMETER IsActive
    Specifies whether the MSIX package is active.

.PARAMETER IsRegularRegistration
    Specifies whether the MSIX package is a regular registration.

.EXAMPLE
    PS C:\> .\Update-AzWvdMsixPackage.ps1 -FullName "MyMsixPackage" -HostPoolName "MyHostPool" -ResourceGroup "MyResourceGroup" -DisplayName "Updated Display Name"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdmsixpackage?view=azps-12.3.0&viewFallbackFrom=azps-12.1.0

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
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$IsActive,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$IsRegularRegistration
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    FullName             = $FullName
    HostPoolName         = $HostPoolName
    ResourceGroup    = $ResourceGroup
}

if ($DisplayName) {
    $parameters['DisplayName'], $DisplayName
}

if ($IsActive) {
    $parameters['IsActive'], $IsActive
}

if ($IsRegularRegistration) {
    $parameters['IsRegularRegistration'], $IsRegularRegistration
}

try {    
    # Update the Azure Virtual Desktop MSIX Package and capture the result
    $result = Update-AzWvdMsixPackage @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop MSIX Package updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop MSIX Package: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
