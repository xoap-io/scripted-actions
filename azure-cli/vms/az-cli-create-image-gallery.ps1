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

.LINK
    https://learn.microsoft.com/en-us/cli/azure/sig
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateSet('eastus', 'eastus2', 'northeurope', 'germanywestcentral', 'westcentralus', 'southcentralus', 'centralus', 'northcentralus', 'eastus2euap', 'westus3', 'southeastasia', 'eastasia', 'japaneast', 'japanwest', 'australiaeast', 'australiasoutheast', 'australiacentral', 'australiacentral2', 'centralindia', 'southindia', 'westindia', 'canadacentral', 'canadaeast', 'uksouth', 'ukwest', 'francecentral', 'francesouth', 'norwayeast', 'norwaywest', 'switzerlandnorth', 'switzerlandwest', 'germanynorth', 'germanywestcentral', 'uaenorth', 'uaecentral', 'southafricanorth', 'southafricawest', 'brazilsouth', 'brazilus', 'koreacentral', 'koreasouth')]
    [string]$AzLocation,

    [Parameter(Mandatory=$true)]
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
    Write-Output "Azure Image Gallery created successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Image Gallery: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
