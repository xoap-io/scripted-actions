<#
.SYNOPSIS
    Create a new Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell. The script creates a new Azure Resource Group and a new Azure VM.
    The script uses the following Azure PowerShell commands:
    New-AzResourceGroup -Name $AzResourceGroupName -Location $AzLocation
    New-AzVm -ResourceGroupName $AzResourceGroupName -Name $AzVmName -Location $AzLocation -ImageName $AzImageName -PublicIpAddressName $AzPublicIpAddressName -Credential $AzVmCredential -OpenPorts $AzOpenPorts -Size $AzVmSize
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

.PARAMETER AzGalleryName
    Defines the name of the Azure Gallery.

.PARAMETER AzImageDefinition
    Defines the name of the Azure Image Definition.

.PARAMETER AzImagePublisher
    Defines the name of the Azure Image Publisher.

.PARAMETER AzImageOffer
    Defines the name of the Azure Image Offer.

.PARAMETER AzImageSku
    Defines the name of the Azure Image SKU.

.PARAMETER AzImageType
    Defines the type of the Azure Image.

.PARAMETER AzOsState
    Defines the state of the Azure OS.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzGalleryName = "myGallery",
    [Parameter(Mandatory)]
    [string]$AzImageDefinition = "myImageDefinition",
    [Parameter(Mandatory)]
    [string]$AzImagePublisher = "MicrosoftWindowsDesktop",
    [Parameter(Mandatory)]
    [string]$AzImageOffer = "Windows-11",
    [Parameter(Mandatory)]
    [string]$AzImageSku = 'win11-23h2-entn',
    [Parameter(Mandatory)]
    [ValidateSet("Windows", "Linux")]
    [string]$AzImageType,
    [Parameter(Mandatory)]
    [ValidateSet("Generalized", "Specialized")]
    [string]$AzOsState
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

az sig image-definition create `
   --resource-group $AzResourceGroupName `
   --gallery-name $AzGalleryName `
   --gallery-image-definition $AzImageDefinition `
   --publisher $AzImagePublisher `
   --offer $AzImageOffer `
   --sku $AzImageSku `
   --os-type $AzImageType `
   --os-state $AzOsState
   