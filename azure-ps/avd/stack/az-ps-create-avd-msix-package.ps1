<#
.SYNOPSIS
    Creates a new MSIX package in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new MSIX package in an Azure Virtual Desktop environment with the specified parameters.
    Uses the New-AzWvdMsixPackage cmdlet from the Az.DesktopVirtualization module.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER FullName
    The full name of the MSIX package.

.PARAMETER DisplayName
    The display name of the MSIX package.

.PARAMETER ImagePath
    The image path of the MSIX package.

.PARAMETER IsActive
    Indicates if the MSIX package is active.

.PARAMETER IsRegularRegistration
    Indicates if the MSIX package is a regular registration.

.PARAMETER LastUpdated
    The last updated date and time of the MSIX package.

.PARAMETER PackageFamilyName
    The family name of the MSIX package.

.PARAMETER PackageName
    The name of the MSIX package.

.PARAMETER PackageRelativePath
    The relative path of the MSIX package.

.PARAMETER PackageAlias
    The alias of the MSIX package.

.PARAMETER Version
    The version of the MSIX package.

.EXAMPLE
    PS C:\> .\New-AzWvdMsixPackage.ps1 -HostPoolName "MyHostPool" -ResourceGroup "MyResourceGroup" -FullName "MyMsixPackage" -DisplayName "My App"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdmsixpackage?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The full name of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [string]$FullName,

    [Parameter(Mandatory=$true, HelpMessage = "The display name of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,

    [Parameter(Mandatory=$false, HelpMessage = "The image path of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImagePath,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the MSIX package is active.")]
    [ValidateNotNullOrEmpty()]
    [switch]$IsActive,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the MSIX package uses regular registration.")]
    [ValidateNotNullOrEmpty()]
    [switch]$IsRegularRegistration,

    [Parameter(Mandatory=$false, HelpMessage = "The last updated date and time of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [datetime]$LastUpdated,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[IMsixPackageApplications[]]$PackageApplication,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[IMsixPackageDependencies[]]$PackageDependency,

    [Parameter(Mandatory=$false, HelpMessage = "The MSIX package family name.")]
    [ValidateNotNullOrEmpty()]
    [string]$PackageFamilyName,

    [Parameter(Mandatory=$false, HelpMessage = "The name of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [string]$PackageName,

    [Parameter(Mandatory=$false, HelpMessage = "The relative path of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [string]$PackageRelativePath,

    [Parameter(Mandatory=$false, HelpMessage = "The alias of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [string]$PackageAlias,

    [Parameter(Mandatory=$false, HelpMessage = "The version string of the MSIX package.")]
    [ValidateNotNullOrEmpty()]
    [string]$Version
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    HostPoolName      = $HostPoolName
    ResourceGroupName = $ResourceGroup
    FullName          = $FullName
}

if ($DisplayName) {
    $parameters['DisplayName'] = $DisplayName
}

if ($ImagePath) {
    $parameters['ImagePath'] = $ImagePath
}

if ($IsActive) {
    $parameters['IsActive'] = $IsActive
}

if ($IsRegularRegistration) {
    $parameters['IsRegularRegistration'] = $IsRegularRegistration
}

if ($LastUpdated) {
    $parameters['LastUpdated'] = $LastUpdated
}

#if ($PackageApplication) {
#    $parameters['PackageApplication'] = $PackageApplication
#}

#if ($PackageDependency) {
#    $parameters['PackageDependency'] = $PackageDependency
#}

if ($PackageFamilyName) {
    $parameters['PackageFamilyName'] = $PackageFamilyName
}

if ($PackageName) {
    $parameters['PackageName'] = $PackageName
}

if ($PackageRelativePath) {
    $parameters['PackageRelativePath'] = $PackageRelativePath
}

if ($PackageAlias) {
    $parameters['PackageAlias'] = $PackageAlias
}

if ($Version) {
    $parameters['Version'] = $Version
}

try {
    # Create the MSIX package and capture the result
    $result = New-AzWvdMsixPackage @parameters

    # Output the result
    Write-Host "✅ MSIX package created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
