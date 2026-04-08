<#
.SYNOPSIS
    Updates an Azure Virtual Desktop MSIX Package.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop MSIX Package.
    Uses the Update-AzWvdMsixPackage cmdlet from the Az.DesktopVirtualization module.

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdmsixpackage?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The full name of the MSIX package to update.")]
    [ValidateNotNullOrEmpty()]
    [string]$FullName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false, HelpMessage = "The display name of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,

    [Parameter(Mandatory=$false, HelpMessage = "Specifies whether the MSIX package is active.")]
    [ValidateNotNullOrEmpty()]
    [switch]$IsActive,

    [Parameter(Mandatory=$false, HelpMessage = "Specifies whether the MSIX package uses regular registration.")]
    [ValidateNotNullOrEmpty()]
    [switch]$IsRegularRegistration
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    FullName          = $FullName
    HostPoolName      = $HostPoolName
    ResourceGroupName = $ResourceGroup
}

if ($DisplayName) {
    $parameters['DisplayName'] = $DisplayName
}

if ($IsActive) {
    $parameters['IsActive'] = $IsActive
}

if ($IsRegularRegistration) {
    $parameters['IsRegularRegistration'] = $IsRegularRegistration
}

try {
    # Update the Azure Virtual Desktop MSIX Package and capture the result
    $result = Update-AzWvdMsixPackage @parameters

    # Output the result
    Write-Host "✅ Azure Virtual Desktop MSIX Package updated successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
