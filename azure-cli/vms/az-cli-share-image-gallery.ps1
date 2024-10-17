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

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzGalleryName
    Defines the name of the Azure Image Gallery.

.PARAMETER EmailAddress
    Defines the email address of the user to assign the Reader role to the Image Gallery.

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
    .\az-cli-share-image-gallery.ps1 -AzResourceGroupName "MyResourceGroup" -AzGalleryName "MyGallery" -EmailAddress "user@example.com"

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroupName = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzGalleryName = "myGallery",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$EmailAddress = "hello@xoap.io",

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
    resource_group   = $AzResourceGroupName
    gallery_name     = $AzGalleryName
    query            = "id"
    role             = "Reader"
    assignee         = $EmailAddress
    scope            = ""
    debug            = $AzDebug
    only_show_errors = $AzOnlyShowErrors
    output           = $AzOutput
    query            = $AzQuery
    verbose          = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Get the Gallery ID
    $GalleryId = az sig show @parameters

    # Update the scope with the Gallery ID
    $parameters.scope = $GalleryId

    # Assign the Reader role to the user
    az role assignment create @parameters

    # Output the result
    Write-Output "Azure Image Gallery shared successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to share the Azure Image Gallery: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}