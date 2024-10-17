<#
.SYNOPSIS
    Create a new Azure Image Gallery with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Image Gallery with the Azure CLI. The script creates a new Azure Resource Group and a new Azure Image Gallery.
    The script uses the following Azure CLI commands:
    az group create --name $AzResourceGroupName --location $AzLocation
    az sig create --resource-group $AzResourceGroupName --gallery-name $AzGalleryName

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzLocation
    Defines the location of the Azure Resource Group.

.PARAMETER AzGalleryName
    Defines the name of the Azure Image Gallery.

.PARAMETER AzSubscription
    Name or ID of subscription.

.PARAMETER AzDebug
    Increase logging verbosity to show all debug logs.

.PARAMETER AzOnlyShowErrors
    Only show errors, suppressing warnings.

.PARAMETER AzOutput
    Output format.

.PARAMETER AzQuery
    JMESPath query string.

.PARAMETER AzVerbose
    Increase logging verbosity.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

.EXAMPLE
    .\az-cli-create-image-gallery.ps1 -AzResourceGroupName "MyResourceGroup" -AzLocation "eastus" -AzGalleryName "MyImageGallery"

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/sig
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroupName = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateSet('eastus', 'eastus2', 'northeurope', 'germanywestcentral', 'westcentralus', 'southcentralus', 'centralus', 'northcentralus', 'eastus2euap', 'westus3', 'southeastasia', 'eastasia', 'japaneast', 'japanwest', 'australiaeast', 'australiasoutheast', 'australiacentral', 'australiacentral2', 'centralindia', 'southindia', 'westindia', 'canadacentral', 'canadaeast', 'uksouth', 'ukwest', 'francecentral', 'francesouth', 'norwayeast', 'norwaywest', 'switzerlandnorth', 'switzerlandwest', 'germanynorth', 'germanywestcentral', 'uaenorth', 'uaecentral', 'southafricanorth', 'southafricawest', 'brazilsouth', 'brazilus', 'koreacentral', 'koreasouth')]
    [string]$AzLocation,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzGalleryName = "myImageGallery",

    [Parameter(Mandatory=$false)]
    [string]$AzSubscription,

    [Parameter(Mandatory=$false)]
    [switch]$AzDebug,

    [Parameter(Mandatory=$false)]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory=$false)]
    [string]$AzOutput,

    [Parameter(Mandatory=$false)]
    [string]$AzQuery,

    [Parameter(Mandatory=$false)]
    [switch]$AzVerbose,


)

# Splatting parameters for better readability
$parameters = @{
    name              = $AzResourceGroupName
    location          = $AzLocation
    gallery_name      = $AzGalleryName
    subscription      = $AzSubscription
    debug             = $AzDebug
    only_show_errors  = $AzOnlyShowErrors
    output            = $AzOutput
    query             = $AzQuery
    verbose           = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create a new Azure Resource Group
    az group create --name $AzResourceGroupName --location $AzLocation

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