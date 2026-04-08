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
    https://learn.microsoft.com/en-us/cli/azure/vm

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Image Gallery")]
    [ValidateNotNullOrEmpty()]
    [string]$AzGalleryName = "myGallery",

    [Parameter(Mandatory = $true, HelpMessage = "The email address of the user to assign the Reader role")]
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
    Write-Host "✅ Azure Image Gallery shared successfully." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
