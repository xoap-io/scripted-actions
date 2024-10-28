<#
.SYNOPSIS
    Creates a new application in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new application in an Azure Virtual Desktop environment with the specified parameters.

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

.PARAMETER AppAlias
    The alias of the application.

.PARAMETER AppType
    The type of the application.

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
    PS C:\> .\New-AzWvdApplication.ps1 -GroupName "MyAppGroup" -AppName "MyApp" -ResourceGroup "MyResourceGroup" -CommandLineSetting "RemoteApp"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdapplication?view=azps-12.3.0

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
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Allow',
        'DoNotAllow',
        'Require'
        )]
    [string]$CommandLineSetting,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$ShowInPortal,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[RemoteApplicationType]$ApplicationType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CommandLineArgument,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$IconIndex,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$IconPath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$MsixPackageApplicationId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$MsixPackageFamilyName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AppAlias
)

# Splatting parameters for better readability
$parameters = @{
    GroupName = $GroupName
    Name = $Name
    ResourceGroup = $ResourceGroup
    CommandLineSetting = $CommandLineSetting
    AppAlias = $AppAlias
}

if ($Description) {
    $parameters['Description'], $BgpCommunity
}

if ($FriendlyName) {
    $parameters['FriendlyName'], $BgpCommunity
}

if ($ShowInPortal) {
    $parameters['ShowInPortal'], $BgpCommunity
}

#if ($ApplicationType) {
#    $parameters['ApplicationType', $BgpCommunity
#}

if ($CommandLineArgument) {
    $parameters['CommandLineArgument'], $BgpCommunity
}

if ($FilePath) {
    $parameters['FilePath'], $BgpCommunity
}

if ($IconIndex) {
    $parameters['IconIndex'], $BgpCommunity
}

if ($IconPath) {
    $parameters['IconPath'], $BgpCommunity
}

if ($MsixPackageApplicationId) {
    $parameters['MsixPackageApplicationId'], $BgpCommunity
}

if ($MsixPackageFamilyName) {
    $parameters['MsixPackageFamilyName'], $BgpCommunity
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the application and capture the result
    $result = New-AzWvdApplication @parameters

    # Output the result
    Write-Output "Application created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the application: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
