<#
.SYNOPSIS
    Create a new Azure Image Gallery with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Image Gallery with the Azure CLI. The script creates a new Azure Resource Group and a new Azure Image Gallery.
    The script uses the following Azure CLI commands:
    az group create --name $AzResourceGroup --location $AzLocation
    az sig create --resource-group $AzResourceGroup --gallery-name $AzGalleryName

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzLocation
    Defines the location of the Azure Resource Group.

.PARAMETER AzGalleryName
    Defines the name of the Azure Image Gallery.

.EXAMPLE
    .\az-cli-create-image-gallery.ps1 -AzResourceGroup "MyResourceGroup" -AzLocation "eastus" -AzGalleryName "MyImageGallery"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/sig

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region for the Image Gallery")]
    [ValidateSet('eastus', 'eastus2', 'northeurope', 'germanywestcentral', 'westcentralus', 'southcentralus', 'centralus', 'northcentralus', 'eastus2euap', 'westus3', 'southeastasia', 'eastasia', 'japaneast', 'japanwest', 'australiaeast', 'australiasoutheast', 'australiacentral', 'australiacentral2', 'centralindia', 'southindia', 'westindia', 'canadacentral', 'canadaeast', 'uksouth', 'ukwest', 'francecentral', 'francesouth', 'norwayeast', 'norwaywest', 'switzerlandnorth', 'switzerlandwest', 'germanynorth', 'germanywestcentral', 'uaenorth', 'uaecentral', 'southafricanorth', 'southafricawest', 'brazilsouth', 'brazilus', 'koreacentral', 'koreasouth')]
    [string]$AzLocation,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Image Gallery")]
    [ValidateNotNullOrEmpty()]
    [string]$AzGalleryName = "myImageGallery"
)

# Splatting parameters for better readability
$parameters = `
    'name', $ResourceGroup
    'location', $Location
    'gallery-name', $GalleryName

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create a new Azure Image Gallery
    az sig create @parameters

    # Output the result
    Write-Host "✅ Azure Image Gallery created successfully." -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
