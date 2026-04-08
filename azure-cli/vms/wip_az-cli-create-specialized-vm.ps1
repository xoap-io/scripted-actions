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
    [string]$AzResourceGroup = 'myResourceGroup',

    [Parameter(Mandatory = $true, HelpMessage = "The ports to open on the Azure VM")]
    [ValidateNotNullOrEmpty()]
    [string]$AzOpenPorts = '3389',

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Machine")]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = 'myVM2',

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the image to use for the VM")]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageId,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region for the resource group")]
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
    Write-Host "✅ Azure specialized VM created successfully." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
