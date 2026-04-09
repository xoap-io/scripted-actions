<#
.SYNOPSIS
    Creates a new version of an Azure Gallery Image.

.DESCRIPTION
    This script creates a new version of an Azure Gallery Image with the Azure CLI.
    The script uses the following Azure CLI command:
    az sig image-version create --resource-group $AzResourceGroup --gallery-name $AzGallery --gallery-image-definition $AzImageDefinition --gallery-image-version $AzGalleryImageVersion --target-regions $AzTargetRegions --replica-count $AzReplicaCount --managed-image /subscriptions/$AzSubscriptionId/resourceGroups/$AzResourceGroup/providers/Microsoft.Compute/virtualMachines/$AzVmName

.PARAMETER AzResourceGroup
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

.EXAMPLE
    .\az-cli-create-image-version.ps1 -AzResourceGroup "MyResourceGroup" -AzGallery "MyGallery" -AzImageDefinition "MyImageDefinition" -AzGalleryImageVersion "1.0.0" -AzTargetRegions "westus" -AzReplicaCount 1 -AzSubscriptionId "00000000-0000-0000-0000-000000000000" -AzVmName "MyVm"

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
    https://learn.microsoft.com/en-us/cli/azure/sig/image-version

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "MyResourceGroup",

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Gallery")]
    [ValidateNotNullOrEmpty()]
    [string]$AzGallery = "MyGallery",

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Image Definition")]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageDefinition = "MyImageDefinition",

    [Parameter(Mandatory = $false, HelpMessage = "The version of the Azure Gallery Image")]
    [ValidateNotNullOrEmpty()]
    [string]$AzGalleryImageVersion = "1.0.0",

    [Parameter(Mandatory = $false, HelpMessage = "The target regions for the Azure Gallery Image")]
    [ValidateNotNullOrEmpty()]
    [string]$AzTargetRegions = "westus",

    [Parameter(Mandatory = $false, HelpMessage = "The replica count of the Azure Gallery Image")]
    [ValidateNotNullOrEmpty()]
    [int]$AzReplicaCount = 1,

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the Azure Subscription")]
    [ValidateNotNullOrEmpty()]
    [string]$AzSubscriptionId = "00000000-0000-0000-0000-000000000000",

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure VM to use as the source image")]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = "MyVm",

    [Parameter(Mandatory = $false, HelpMessage = "The location of the Azure Gallery Image Version")]
    [string]$AzLocation = "westus",

    [Parameter(Mandatory = $false, HelpMessage = "Excludes the image version from the latest version")]
    [switch]$AzExcludeFromLatest,

    [Parameter(Mandatory = $false, HelpMessage = "The end of life date for the image version")]
    [datetime]$AzEndOfLifeDate,

    [Parameter(Mandatory = $false, HelpMessage = "The storage account type for the image version")]
    [string]$AzStorageAccountType = "Standard_LRS",

    [Parameter(Mandatory = $false, HelpMessage = "Tags for the image version")]
    [hashtable]$AzTags
)

# Splatting parameters for better readability
$parameters = @{
    resource_group            = $AzResourceGroup
    gallery_name              = $AzGallery
    gallery_image_definition  = $AzImageDefinition
    gallery_image_version     = $AzGalleryImageVersion
    target_regions            = $AzTargetRegions
    replica_count             = $AzReplicaCount
    managed_image             = "/subscriptions/$AzSubscriptionId/resourceGroups/$AzResourceGroup/providers/Microsoft.Compute/virtualMachines/$AzVmName"
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
    Write-Host "✅ Azure Gallery Image version created successfully." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
