<#
.SYNOPSIS
    Creates a new version of an Azure Gallery Image.

.DESCRIPTION
    This script creates a new version of an Azure Gallery Image with the Azure CLI.
    The script uses the following Azure CLI command:
    az sig image-version create --resource-group $AzResourceGroupName --gallery-name $AzGallery --gallery-image-definition $AzImageDefinition --gallery-image-version $AzGalleryImageVersion --target-regions $AzTargetRegions --replica-count $AzReplicaCount --managed-image /subscriptions/$AzSubscriptionId/resourceGroups/$AzResourceGroupName/providers/Microsoft.Compute/virtualMachines/$AzVmName

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzGallery
    Defines the name of the Azure Gallery.

.PARAMETER AzImageDefinition
    Defines the name of the Azure Image Definition.

.PARAMETER AzGalleryImageVersion
    Defines the version of the Azure Gallery Image.

.PARAMETER AzTargetRegions
    Defines the target regions for the Azure Gallery Image.

.PARAMETER AzReplicaCount
    Defines the replica count of the Azure Gallery Image.

.PARAMETER AzSubscriptionId
    Defines the ID of the Azure Subscription.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

.PARAMETER AzLocation
    Defines the location of the Azure Gallery Image Version.

.PARAMETER AzExcludeFromLatest
    Excludes the image version from the latest version.

.PARAMETER AzEndOfLifeDate
    Defines the end of life date for the image version.

.PARAMETER AzStorageAccountType
    Defines the storage account type for the image version.

.PARAMETER AzTags
    Defines the tags for the image version.

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
    .\az-cli-create-image-version.ps1 -AzResourceGroupName "MyResourceGroup" -AzGallery "MyGallery" -AzImageDefinition "MyImageDefinition" -AzGalleryImageVersion "1.0.0" -AzTargetRegions "westus" -AzReplicaCount 1 -AzSubscriptionId "00000000-0000-0000-0000-000000000000" -AzVmName "MyVm"

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/sig/image-version
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroupName = "MyResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzGallery = "MyGallery",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageDefinition = "MyImageDefinition",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzGalleryImageVersion = "1.0.0",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzTargetRegions = "westus",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int]$AzReplicaCount = 1,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzSubscriptionId = "00000000-0000-0000-0000-000000000000",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = "MyVm",

    [Parameter(Mandatory=$false)]
    [string]$AzLocation = "westus",

    [Parameter(Mandatory=$false)]
    [switch]$AzExcludeFromLatest,

    [Parameter(Mandatory=$false)]
    [datetime]$AzEndOfLifeDate,

    [Parameter(Mandatory=$false)]
    [string]$AzStorageAccountType = "Standard_LRS",

    [Parameter(Mandatory=$false)]
    [hashtable]$AzTags,

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
    resource_group            = $AzResourceGroupName
    gallery_name              = $AzGallery
    gallery_image_definition  = $AzImageDefinition
    gallery_image_version     = $AzGalleryImageVersion
    target_regions            = $AzTargetRegions
    replica_count             = $AzReplicaCount
    managed_image             = "/subscriptions/$AzSubscriptionId/resourceGroups/$AzResourceGroupName/providers/Microsoft.Compute/virtualMachines/$AzVmName"
    location                  = $AzLocation
    exclude_from_latest       = $AzExcludeFromLatest
    end_of_life_date          = $AzEndOfLifeDate
    storage_account_type      = $AzStorageAccountType
    tags                      = $AzTags
    subscription              = $AzSubscriptionId
    debug                     = $AzDebug
    only_show_errors          = $AzOnlyShowErrors
    output                    = $AzOutput
    query                     = $AzQuery
    verbose                   = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create a new version of an Azure Gallery Image
    az sig image-version create @parameters

    # Output the result
    Write-Output "Azure Gallery Image version created successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to create the Azure Gallery Image version: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}