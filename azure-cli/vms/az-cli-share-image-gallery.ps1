<#
.SYNOPSIS
    Share an Azure Image Gallery with a user.

.DESCRIPTION
    This script shares an Azure Image Gallery with a user. The script uses the Azure CLI to assign the Reader role to the Image Gallery for the specified user.

    The script uses the following Azure CLI commands:
    az sig show `
        --resource-group $AzResourceGroupName `
        --gallery-name $AzGalleryName `
        --query id

    az role assignment create `
        --role "Reader" `
        --assignee $EmailAddress `
        --scope $GalleryId

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
    azure-cli/bicep/az-cli-deploy-bicep.ps1

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzGalleryName
    Defines the name of the Azure Image Gallery.

.PARAMETER EmailAddress
    Defines the email address of the user to assign the Reader role to the Image Gallery.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzGalleryName,
    [Parameter(Mandatory)]
    [string]$EmailAddress
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

$GalleryId = az sig show `
   --resource-group $AzResourceGroupName `
   --gallery-name $AzGalleryName `
   --query id

az role assignment create `
   --role "Reader" `
   --assignee $EmailAddress `
   --scope $GalleryId
