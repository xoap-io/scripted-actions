<#
.SYNOPSIS
    Create an Azure Virtual Network and Subnet.

.DESCRIPTION
    This script creates an Azure Virtual Network and Subnet.
    The script uses the following Azure CLI command:
    az network vnet create --name $AzVnetName --resource-group $AzResourceGroupName --address-prefixes $AzVnetAddressPrefix --subnet-name $AzSubnetName --subnet-prefixes $AzSsubnetAddressPrefix

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

.PARAMETER AzVnetName
    Defines the name of the Azure Virtual Network.

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzVnetAddressPrefix
    Defines the address prefix for the Azure Virtual Network.

.PARAMETER AzSubnetName
    Defines the name of the Azure Subnet.

.PARAMETER AzSsubnetAddressPrefix
    Defines the address prefix for the Azure Subnet.
    
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzVnetName,
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzVnetAddressPrefix,
    [Parameter(Mandatory)]
    [string]$AzSubnetName,
    [Parameter(Mandatory)]
    [string]$AzSsubnetAddressPrefix
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

# Create a virtual network and subnet
az network vnet create `
    --name $AzVnetName `
    --resource-group $AzResourceGroupName `
    --address-prefixes $AzVnetAddressPrefix `
    --subnet-name $AzSubnetName `
    --subnet-prefixes $AzSsubnetAddressPrefix
