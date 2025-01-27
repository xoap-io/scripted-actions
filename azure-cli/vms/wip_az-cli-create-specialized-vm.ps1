<#
.SYNOPSIS
    Create an Azure specialized VM from an existing image.

.DESCRIPTION
    This script creates an Azure specialized VM from an existing image in a shared image gallery. It registers necessary providers, creates a resource group, and creates a VM with the specified parameters.

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzOpenPorts
    Defines the ports to open on the Azure Virtual Machine.

.PARAMETER AzVmName
    Defines the name of the Azure Virtual Machine.

.PARAMETER AzImageId
    Defines the ID of the image to use for the VM.

.PARAMETER AzLocation
    Defines the location for the resource group.

.EXAMPLE
    .\wip_az-cli-create-specialized-vm.ps1 -AzResourceGroup "myResourceGroup" -AzOpenPorts "3389" -AzVmName "myVM2" -AzImageId "/subscriptions/<Subscription ID>/resourceGroups/myGalleryRG/providers/Microsoft.Compute/galleries/myGallery/images/myImageDefinition" -AzLocation "eastus"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = 'myResourceGroup',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzOpenPorts = '3389',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = 'myVM2',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzLocation = 'eastus'
)

# Splatting parameters for better readability
$parameters = @{
    resource_group   = $AzResourceGroup
    open_ports       = $AzOpenPorts
    vm_name          = $AzVmName
    image_id         = $AzImageId
    location         = $AzLocation
    debug            = $AzDebug
    only_show_errors = $AzOnlyShowErrors
    output           = $AzOutput
    query            = $AzQuery
    verbose          = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Register necessary providers
    az provider register -n Microsoft.VirtualMachineImages
    az provider register -n Microsoft.Compute
    az provider register -n Microsoft.KeyVault
    az provider register -n Microsoft.Storage
    az provider register -n Microsoft.Network
    az provider register -n Microsoft.ContainerInstance

    # Create resource group
    az group create --name $parameters.resource_group --location $parameters.location

    # Create specialized VM
    az vm create `
        --resource-group $parameters.resource_group `
        --name $parameters.vm_name `
        --image $parameters.image_id `
        --specialized

    # Open specified ports
    az vm open-port `
        --resource-group $parameters.resource_group `
        --name $parameters.vm_name `
        --port $parameters.open_ports

    # Output the result
    Write-Output "Azure specialized VM created successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to create Azure specialized VM: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}