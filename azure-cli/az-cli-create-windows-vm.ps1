<#
.SYNOPSIS
    Create a new Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell. The script creates a new Azure Resource Group, a new Azure VM, and a new Azure Public IP Address.
    The script also retrieves the public IP address of the VM.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT


.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.Parameter AzResourceGroupName
    Defines the name of the Azure Resource Group.

.Parameter AzVmName
    Defines the name of the Azure VM.

.Parameter AzLocation
    Defines the location of the Azure VM.

.Parameter AzImageName
    Defines the name of the Azure VM image.

.Parameter AzPublicIpAddressName
    Defines the name of the Azure VM public IP address.

.Parameter AzVmUserName
    Defines the name of the Azure VM user.

.Parameter AzVmUserPassword
    Defines the password of the Azure VM user.

.Parameter AZOpenPorts
    Defines the open ports of the Azure VM.

.Parameter AzVmSize
    Defines the size of the Azure VM.

#>

param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzVmName,
    [Parameter(Mandatory)]
    [string]$AzLocation,
    [Parameter(Mandatory)]
    [string]$AzImageName,
    [Parameter(Mandatory)]
    [string]$AzPublicIpAddressName,
    [Parameter(Mandatory)]
    [string]$AzVmUserName,
    [Parameter(Mandatory)]
    [string]$AzVmUserPassword,
    [Parameter(Mandatory)]
    [string]$AZOpenPorts = '3389',
    [Parameter(Mandatory)]
    [string]$AzVmSize
)

# Create a new Azure Resource Group
az group create \
	--name $AzResourceGroupName \
	--location $AzLocation

# Create a new Azure VM
az vm create \
	--resource-group $AzResourceGroupName \
	--name $AzVmName \
	--image AzImageName \
	--public-ip-sku Standard \
	--admin-username $AzVmUserName \
	--admin-password $AzVmUserPassword \
	--nsg-rule $AZOpenPorts \
	--size AzVmSize