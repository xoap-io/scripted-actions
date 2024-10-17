<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Application.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Application.

.PARAMETER GroupName
    The name of the application group.

.PARAMETER Name
    The name of the application.

.PARAMETER ResourceGroupName
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

.PARAMETER Tag
    A hashtable of tags to assign to the application.

.EXAMPLE
    PS C:\> .\Update-AzWvdApplication.ps1 -GroupName "MyAppGroup" -Name "MyApplication" -ResourceGroupName "MyResourceGroup" -Description "Updated Description"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdapplication?view=azps-12.2.0

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
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "InBuilt",
        "MsixPackage"
    )]
    [string]$ApplicationType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CommandLineArgument,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Allow",
        "DoNotAllow",
        "Require"
    )]
    [CommandLineSetting]$CommandLineSetting,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

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

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$ShowInPortal,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Splatting parameters for better readability
$parameters = @{
    GroupName         = $GroupName
    Name              = $Name
    ResourceGroupName = $ResourceGroupName
}

if ($ApplicationType) {
    $parameters['ApplicationType', $ApplicationType
}

if ($CommandLineArgument) {
    $parameters['CommandLineArgument', $CommandLineArgument
}

if ($CommandLineSetting) {
    $parameters['CommandLineSetting', $CommandLineSetting
}

if ($Description) {
    $parameters['Description', $Description
}

if ($FilePath) {
    $parameters['FilePath', $FilePath
}

if ($FriendlyName) {
    $parameters['FriendlyName', $FriendlyName
}

if ($IconIndex) {
    $parameters['IconIndex', $IconIndex
}

if ($IconPath) {
    $parameters['IconPath', $IconPath
}

if ($MsixPackageApplicationId) {
    $parameters['MsixPackageApplicationId', $MsixPackageApplicationId
}

if ($MsixPackageFamilyName) {
    $parameters['MsixPackageFamilyName', $MsixPackageFamilyName
}

if ($ShowInPortal) {
    $parameters['ShowInPortal', $ShowInPortal
}

if ($Tags) {
    $parameters['Tag', $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Update the Azure Virtual Desktop Application and capture the result
    $result = Update-AzWvdApplication @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Application updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop Application: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
