<#
.SYNOPSIS
    Create a new Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell.
    The script uses the Azure PowerShell to create the specified Azure VM.
    The script uses the following Azure PowerShell command:
    New-AzVM -ResourceGroupName $AzResourceGroupName -Name $AzVmName -Location $AzLocation -Image $AzImageName -PublicIpAddressName $AzPublicIpAddressName -Credential $AzVmCred -OpenPorts $AzOpenPorts -Size $AzVmSize
    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    Azure CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzGallery
    Defines the name of the Azure Gallery.

.PARAMETER AzImageDefinition
    Defines the name of the Azure Image Definition.

.PARAMETER AzGalleryImageVersion
    Defines the version of the Azure Gallery Image.

.PARAMETER AzTargetRegions
    Defines the target regions of the Azure Gallery Image.

.PARAMETER AzReplicaCount
    Defines the replica count of the Azure Gallery Image.

.PARAMETER AzSubscriptionId
    Defines the ID of the Azure Subscription.

.PARAMETER AzVmName
    Defines the name of the Azure VM.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzGallery,
    [Parameter(Mandatory)]
    [string]$AzImageDefinition,
    [Parameter(Mandatory)]
    [string]$AzGalleryImageVersion,
    [Parameter(Mandatory)]
    [string]$AzTargetRegions,
    [Parameter(Mandatory)]
    [string]$AzReplicaCount,
    [Parameter(Mandatory)]
    [string]$AzSubscriptionId,
    [Parameter(Mandatory)]
    [string]$AzVmName
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az sig image-version create `
    --resource-group $AzResourceGroupName `
    --gallery-name $AzGallery `
    --gallery-image-definition $AzImageDefinition `
    --gallery-image-version $AzGalleryImageVersion `
    --target-regions $AzTargetRegions `
    --replica-count $AzReplicaCount `
    --managed-image "/subscriptions/$AzSubscriptionId/resourceGroups/MyResourceGroup/providers/Microsoft.Compute/virtualMachines/$AzVmName"
