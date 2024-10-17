<#
.SYNOPSIS
    Creates a new MSIX package in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new MSIX package in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER HostPoolName
    The name of the host pool.

.PARAMETER ResourceGroupName
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

.PARAMETER PackageApplication
    The applications in the MSIX package.

.PARAMETER PackageDependency
    The dependencies of the MSIX package.

.PARAMETER PackageFamilyName
    The family name of the MSIX package.

.PARAMETER PackageName
    The name of the MSIX package.

.PARAMETER PackageRelativePath
    The relative path of the MSIX package.

.PARAMETER Version
    The version of the MSIX package.

.EXAMPLE
    PS C:\> .\New-AzWvdMsixPackage.ps1 -HostPoolName "MyHostPool" -ResourceGroupName "MyResourceGroup" -FullName "MyMsixPackage"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdmsixpackage?view=azps-12.3.0

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
    [string]$ResourceGroupName,
 
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$FullName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ImagePath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$IsActive,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$IsRegularRegistration,

    [Parameter(Mandatory=$false)]
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

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageFamilyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageRelativePath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageAlias,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Version
)

# Splatting parameters for better readability
$parameters = @{
    HostPoolName      = $HostPoolName
    ResourceGroupName = $ResourceGroupName
    FullName          = $FullName
}

if ($DisplayName) {
    $parameters['DisplayName'], $DisplayName
}

if ($ImagePath) {
    $parameters['ImagePath'], $ImagePath
}

if ($IsActive) {
    $parameters['IsActive'], $IsActive
}

if ($IsRegularRegistration) {
    $parameters['IsRegularRegistration'], $IsRegularRegistration
}

if ($LastUpdated) {
    $parameters['LastUpdated'], $LastUpdated
}

#if ($PackageApplication) {
#    $parameters['PackageApplication'], $PackageApplication
#}

#if ($PackageDependency) {
#    $parameters['PackageDependency'], $PackageDependency
#}

if ($PackageFamilyName) {
    $parameters['PackageFamilyName'], $PackageFamilyName
}

if ($PackageName) {
    $parameters['PackageName'], $PackageName
}

if ($PackageRelativePath) {
    $parameters['PackageRelativePath'], $PackageRelativePath
}

if ($Version) {
    $parameters['Version'], $Version
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {    
    # Create the MSIX package and capture the result
    $result = New-AzWvdMsixPackage @parameters

    # Output the result
    Write-Output "MSIX package created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the MSIX package: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
