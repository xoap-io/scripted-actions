<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Application.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Application.
    Uses the Update-AzWvdApplication cmdlet from the Az.DesktopVirtualization module.

.PARAMETER GroupName
    The name of the application group.

.PARAMETER Name
    The name of the application.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER ApplicationType
    The type of the application.

.PARAMETER CommandLineArgument
    The command line argument for the application.

.PARAMETER CommandLineSetting
    The command line setting for the application.

.PARAMETER Description
    The description of the application.

.PARAMETER FilePath
    The file path of the application.

.PARAMETER FriendlyName
    The friendly name of the application.

.PARAMETER IconIndex
    The index of the icon.

.PARAMETER IconPath
    The path to the icon.

.PARAMETER MsixPackageApplicationId
    The MSIX package application ID.

.PARAMETER MsixPackageFamilyName
    The MSIX package family name.

.PARAMETER ShowInPortal
    Specifies whether to show the application in the portal.

.PARAMETER Tags
    A hashtable of tags to assign to the application.

.EXAMPLE
    PS C:\> .\Update-AzWvdApplication.ps1 -GroupName "MyAppGroup" -Name "MyApplication" -ResourceGroup "MyResourceGroup" -Description "Updated Description"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdapplication?view=azps-12.2.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the application to update.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false, HelpMessage = "The type of the application.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "InBuilt",
        "MsixPackage"
    )]
    [string]$ApplicationType,

    [Parameter(Mandatory=$false, HelpMessage = "The command line argument for the application.")]
    [ValidateNotNullOrEmpty()]
    [string]$CommandLineArgument,

    [Parameter(Mandatory=$false, HelpMessage = "The command line setting (Allow, DoNotAllow, or Require).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Allow",
        "DoNotAllow",
        "Require"
    )]
    [string]$CommandLineSetting,

    [Parameter(Mandatory=$false, HelpMessage = "The description of the application.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "The file path of the application executable.")]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter(Mandatory=$false, HelpMessage = "The friendly display name of the application.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false, HelpMessage = "The icon index within the icon file.")]
    [ValidateNotNullOrEmpty()]
    [int]$IconIndex,

    [Parameter(Mandatory=$false, HelpMessage = "The path to the application icon file.")]
    [ValidateNotNullOrEmpty()]
    [string]$IconPath,

    [Parameter(Mandatory=$false, HelpMessage = "The MSIX package application ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$MsixPackageApplicationId,

    [Parameter(Mandatory=$false, HelpMessage = "The MSIX package family name.")]
    [ValidateNotNullOrEmpty()]
    [string]$MsixPackageFamilyName,

    [Parameter(Mandatory=$false, HelpMessage = "Specifies whether to show the application in the portal.")]
    [ValidateNotNullOrEmpty()]
    [switch]$ShowInPortal,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to assign to the application.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    GroupName         = $GroupName
    Name              = $Name
    ResourceGroupName = $ResourceGroup
}

if ($ApplicationType) {
    $parameters['ApplicationType'] = $ApplicationType
}

if ($CommandLineArgument) {
    $parameters['CommandLineArgument'] = $CommandLineArgument
}

if ($CommandLineSetting) {
    $parameters['CommandLineSetting'] = $CommandLineSetting
}

if ($Description) {
    $parameters['Description'] = $Description
}

if ($FilePath) {
    $parameters['FilePath'] = $FilePath
}

if ($FriendlyName) {
    $parameters['FriendlyName'] = $FriendlyName
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

if ($ShowInPortal) {
    $parameters['ShowInPortal'] = $ShowInPortal
}

if ($Tags) {
    $parameters['Tag'] = $Tags
}

try {
    # Update the Azure Virtual Desktop Application and capture the result
    $result = Update-AzWvdApplication @parameters

    # Output the result
    Write-Host "✅ Azure Virtual Desktop Application updated successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
