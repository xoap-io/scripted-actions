<#
.SYNOPSIS
    Delete an Azure Image Builder Linux VM and its associated resources.

.DESCRIPTION
    This script deletes an Azure Image Builder Linux VM and its associated resources, including the image template, role assignments, identities, image versions, image definitions, and the resource group.

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzOpenPorts
    Defines the ports to open on the Azure Virtual Machine.

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
    .\wip_az-cli-delete-image-builder-linux.ps1 -AzResourceGroupName "myResourceGroup" -AzOpenPorts "3389"

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
    [string]$AzResourceGroupName = 'myResourceGroup',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzOpenPorts = '3389',

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
    open_ports       = $AzOpenPorts
    debug            = $AzDebug
    only_show_errors = $AzOnlyShowErrors
    output           = $AzOutput
    query            = $AzQuery
    verbose          = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Delete the image template
    az resource delete `
        --resource-group $parameters.resource_group `
        --resource-type Microsoft.VirtualMachineImages/imageTemplates `
        --name helloImageTemplateforSIG01 `
        --no-wait

    # Delete the role assignment
    az role assignment delete `
        --assignee $imgBuilderCliId `
        --role "$imageRoleDefName" `
        --scope /subscriptions/$subscriptionID/resourceGroups/$parameters.resource_group

    # Delete the role definition
    az role definition delete --name "$imageRoleDefName"

    # Delete the identity
    az identity delete --ids $imgBuilderId

    # Get the image version
    $sigDefImgVersion = az sig image-version list `
        -g $parameters.resource_group `
        --gallery-name $sigName `
        --gallery-image-definition $imageDefName `
        --subscription $subscriptionID --query [].'name' -o json | grep 0. | tr -d '"'

    # Delete the image version
    az sig image-version delete `
        -g $parameters.resource_group `
        --gallery-image-version $sigDefImgVersion `
        --gallery-name $sigName `
        --gallery-image-definition $imageDefName `
        --subscription $subscriptionID

    # Delete the image definition
    az sig image-definition delete `
        -g $parameters.resource_group `
        --gallery-name $sigName `
        --gallery-image-definition $imageDefName `
        --subscription $subscriptionID

    # Delete the shared image gallery
    az sig delete -r $sigName -g $parameters.resource_group

    # Delete the resource group
    az group delete -n $parameters.resource_group -y

    # Output the result
    Write-Output "Azure Image Builder Linux VM and associated resources deleted successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to delete Azure Image Builder Linux VM and associated resources: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}