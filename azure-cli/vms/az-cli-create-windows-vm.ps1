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
    Azure CLI

.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

.PARAMETER AzLocation
    Defines the location of the Azure VM.

.PARAMETER AzImageName
    Defines the name of the Azure VM image.

.PARAMETER AzPublicIpAddressName
    Defines the name of the Azure VM public IP address.

.PARAMETER AzVmUserName
    Defines the name of the Azure VM user.

.PARAMETER AzVmUserPassword
    Defines the password of the Azure VM user.

.PARAMETER AzOpenPorts
    Defines the open ports of the Azure VM.

.PARAMETER AzVmSize
    Defines the size of the Azure VM.

#>

param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "MyResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzVmName = "MyVm",
    [Parameter(Mandatory)]
    [ValidateSet('eastus', 'eastus2', 'germany', 'northeurope', 'germanywestcentral', 'westcentralus', 'southcentralus', 'southcentralus', 'centralus', 'northcentralus', 'eastus2euap', 'westus3', 'southeastasia', 'eastasia', 'japaneast', 'japanwest', 'australiaeast', 'australiasoutheast', 'australiacentral', 'australiacentral2', 'centralindia', 'southindia', 'westindia', 'canadacentral', 'canadaeast', 'uksouth', 'ukwest', 'francecentral', 'francesouth', 'norwayeast', 'norwaywest', 'switzerlandnorth', 'switzerlandwest', 'germanynorth', 'germanywestcentral', 'uaenorth', 'uaecentral', 'southafricanorth', 'southafricawest', 'brazilsouth', 'brazilus', 'koreacentral', 'koreasouth', 'koreasouth', 'australiacentral', 'australiacentral2', 'australiaeast', 'australiasoutheast', 'canadacentral', 'canadaeast', 'centralindia', 'eastasia', 'eastus', 'eastus2', 'eastus2euap', 'francecentral', 'francesouth', 'germanywestcentral', 'japaneast', 'japanwest', 'northcentralus', 'northeurope', 'southafricanorth', 'southcentralus', 'southeastasia', 'switzerlandnorth', 'switzerlandwest', 'uksouth', 'ukwest', 'westcentralus', 'westeurope', 'westindia', 'westus', 'westus2')]
    [string]$AzLocation,
    [Parameter(Mandatory)]
    [string]$AzImageName = "Win2019Datacenter",
    [Parameter(Mandatory)]
    [string]$AzPublicIpAddressName = "MyPublicIpAddress",
    [Parameter(Mandatory)]
    [string]$AzVmUserName = "MyVmUser",
    [Parameter(Mandatory)]
    [Securestring]$AzVmUserPassword = "MyVmUserPassword",
    [Parameter(Mandatory)]
    [string]$AzOpenPorts = '3389',
    [Parameter(Mandatory)]
    [ValidateSet('Standard_A0', 'Standard_A1', 'Standard_A2', 'Standard_A3', 'Standard_A4', 'Standard_A5', 'Standard_A6', 'Standard_A7', 'Standard_A8', 'Standard_A9', 'Standard_A10', 'Standard_A11', 'Standard_A1_v2', 'Standard_A2_v2', 'Standard_A4_v2', 'Standard_A8_v2', 'Standard_A2m_v2', 'Standard_A4m_v2', 'Standard_A8m_v2', 'Standard_B1s', 'Standard_B1ms', 'Standard_B2s', 'Standard_B2ms', 'Standard_B4ms', 'Standard_B8ms', 'Standard_B12ms', 'Standard_B16ms', 'Standard_B20ms', 'Standard_B24ms', 'Standard_B1ls', 'Standard_B1s', 'Standard_B2s', 'Standard_B4s', 'Standard_B8s', 'Standard_B12s', 'Standard_B16s', 'Standard_B20s', 'Standard_B24s', 'Standard_D1', 'Standard_D2', 'Standard_D3', 'Standard_D4', 'Standard_D11', 'Standard_D12', 'Standard_D13', 'Standard_D14', 'Standard_D1_v2', 'Standard_D2_v2', 'Standard_D3_v2', 'Standard_D4_v2', 'Standard_D5_v2', 'Standard_D11_v2', 'Standard_D12_v2', 'Standard_D13_v2', 'Standard_D14_v2', 'Standard_D15_v2', 'Standard_D2_v3', 'Standard_D4_v3', 'Standard_D8_v3', 'Standard_D16_v3', 'Standard_D32_v3', 'Standard_D48_v3', 'Standard_D64_v3', 'Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_D8s_v3', 'Standard_D16s_v3', 'Standard_D32s_v3', 'Standard_D48s_v3', 'Standard_D64s_v3', 'Standard_D2_v4', 'Standard_D4_v4', 'Standard_D8_v4', 'Standard_D16_v4', 'Standard_D32_v4', 'Standard_D48_v4', 'Standard_D64_v4', 'Standard_D2s_v4')]
    [string]$AzVmSize
)

# Create a new Azure Resource Group
az group create `
	--name $AzResourceGroupName `
	--location $AzLocation

# Create a new Azure VM
az vm create `
	--resource-group $AzResourceGroupName `
	--name $AzVmName `
	--image $AzImageName `
	--public-ip-sku Standard `
	--admin-username $AzVmUserName `
	--admin-password $AzVmUserPassword `
	--nsg-rule $AzOpenPorts `
	--size $AzVmSize
