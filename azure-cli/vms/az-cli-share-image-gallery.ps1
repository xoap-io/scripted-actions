<#
.SYNOPSIS
    Share an Azure Image Gallery with a user.

.DESCRIPTION
    This script shares an Azure Image Gallery with a user. The script uses the Azure CLI to assign the Reader role to the Image Gallery for the specified user.

    The script uses the following Azure CLI commands:
    az sig show `
        --resource-group $AzResourceGroup `
        --gallery-name $AzGalleryName `
        --query id

    az role assignment create `
        --role "Reader" `
        --assignee $EmailAddress `
        --scope $GalleryId

.PARAMETER AzResourceGroup
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
    .\az-cli-share-image-gallery.ps1 -AzResourceGroup "MyResourceGroup" -AzGalleryName "MyGallery" -EmailAddress "user@example.com"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzGalleryName = "myGallery",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$EmailAddress = "hello@xoap.io"
)

# Splatting parameters for better readability
$parameters = @{
    resource_group   = $AzResourceGroup
    gallery_name     = $AzGalleryName
    query            = "id"
    role             = "Reader"
    assignee         = $EmailAddress
    scope            = ""
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