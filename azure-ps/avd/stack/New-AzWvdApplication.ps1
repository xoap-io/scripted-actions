<#
.SYNOPSIS
    Creates a new application in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new application in an Azure Virtual Desktop environment with the specified parameters.
    Uses the New-AzWvdApplication cmdlet from the Az.DesktopVirtualization module.

.PARAMETER GroupName
    The name of the application group.

.PARAMETER Name
    The name of the application.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER CommandLineSetting
    The command line setting for the application.

.PARAMETER Description
    The description of the application.

.PARAMETER FriendlyName
    The friendly name of the application.

.PARAMETER ShowInPortal
    Indicates if the application should be shown in the portal.

.PARAMETER CommandLineArgument
    The command line argument for the application.

.PARAMETER FilePath
    The file path of the application.

.PARAMETER IconIndex
    The icon index of the application.

.PARAMETER IconPath
    The icon path of the application.

.PARAMETER MsixPackageApplicationId
    The MSIX package application ID.

.PARAMETER MsixPackageFamilyName
    The MSIX package family name.

.PARAMETER AppAlias
    The alias of the application.

.EXAMPLE
    PS C:\> .\New-AzWvdApplication.ps1 -GroupName "MyAppGroup" -Name "MyApp" -ResourceGroup "MyResourceGroup" -CommandLineSetting "DoNotAllow" -AppAlias "notepad"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdapplication?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the application.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The command line setting (Allow, DoNotAllow, or Require).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Allow',
        'DoNotAllow',
        'Require'
        )]
    [string]$CommandLineSetting,

    [Parameter(Mandatory=$false, HelpMessage = "Description of the application.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "Friendly display name of the application.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false, HelpMessage = "Show this application in the portal.")]
    [ValidateNotNullOrEmpty()]
    [switch]$ShowInPortal,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[RemoteApplicationType]$ApplicationType,

    [Parameter(Mandatory=$false, HelpMessage = "Command line argument for the application.")]
    [ValidateNotNullOrEmpty()]
    [string]$CommandLineArgument,

    [Parameter(Mandatory=$false, HelpMessage = "File path of the application executable.")]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter(Mandatory=$false, HelpMessage = "Icon index within the icon file.")]
    [ValidateNotNullOrEmpty()]
    [int]$IconIndex,

    [Parameter(Mandatory=$false, HelpMessage = "Path to the application icon file.")]
    [ValidateNotNullOrEmpty()]
    [string]$IconPath,

    [Parameter(Mandatory=$false, HelpMessage = "The MSIX package application ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$MsixPackageApplicationId,

    [Parameter(Mandatory=$false, HelpMessage = "The MSIX package family name.")]
    [ValidateNotNullOrEmpty()]
    [string]$MsixPackageFamilyName,

    [Parameter(Mandatory=$true, HelpMessage = "The application alias used to identify the app.")]
    [ValidateNotNullOrEmpty()]
    [string]$AppAlias
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    GroupName = $GroupName
    Name = $Name
    ResourceGroupName = $ResourceGroup
    CommandLineSetting = $CommandLineSetting
    AppAlias = $AppAlias
}

if ($Description) {
    $parameters['Description'] = $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'] = $FriendlyName
}

if ($ShowInPortal) {
    $parameters['ShowInPortal'] = $ShowInPortal
}

#if ($ApplicationType) {
#    $parameters['ApplicationType'] = $ApplicationType
#}

if ($CommandLineArgument) {
    $parameters['CommandLineArgument'] = $CommandLineArgument
}

if ($FilePath) {
    $parameters['FilePath'] = $FilePath
}

if ($IconIndex) {
    $parameters['IconIndex'] = $IconIndex
}

if ($IconPath) {
    $parameters['IconPath'] = $IconPath
}

if ($MsixPackageApplicationId) {
    $parameters['MsixPackageApplicationId'] = $MsixPackageApplicationId
}

if ($MsixPackageFamilyName) {
    $parameters['MsixPackageFamilyName'] = $MsixPackageFamilyName
}

try {
    # Create the application and capture the result
    $result = New-AzWvdApplication @parameters

    # Output the result
    Write-Host "✅ Application created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
