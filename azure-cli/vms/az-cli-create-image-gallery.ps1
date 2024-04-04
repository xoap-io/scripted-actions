<#
.SYNOPSIS
    Create a new Azure Image Gallery with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Image Gallery with the Azure CLI. The script creates a new Azure Resource Group and a new Azure Image Gallery.
    The script uses the following Azure CLI commands:
    az group create --name $AzResourceGroupName --location $AzLocation
    az sig create --resource-group $AzResourceGroupName --gallery-name $AzGalleryName

    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    Azure CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzLocation
    Defines the location of the Azure Resource Group.

.PARAMETER AzGalleryName
    Defines the name of the Azure Image Gallery.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzLocation,
    [Parameter(Mandatory)]
    [string]$AzGalleryName
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az group create `
    --name $AzResourceGroupName `
    --location $AzLocation

az sig create `
    --resource-group $AzResourceGroupName `
    --gallery-name $AzGalleryName
