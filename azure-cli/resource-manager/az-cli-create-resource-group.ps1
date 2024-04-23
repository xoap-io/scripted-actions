<#
.SYNOPSIS
    Create a new Azure Resource Group with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Resource Group with the Azure CLI.
    The script uses the following Azure CLI command:
    az group create --name $AzResourceGroupName --location $AzLocation

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

.PARAMETER AzLocation
    Defines the location of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [ValidateSet('eastus', 'eastus2', 'germany', 'northeurope', 'germanywestcentral', 'westcentralus', 'southcentralus', 'southcentralus', 'centralus', 'northcentralus', 'eastus2euap', 'westus3', 'southeastasia', 'eastasia', 'japaneast', 'japanwest', 'australiaeast', 'australiasoutheast', 'australiacentral', 'australiacentral2', 'centralindia', 'southindia', 'westindia', 'canadacentral', 'canadaeast', 'uksouth', 'ukwest', 'francecentral', 'francesouth', 'norwayeast', 'norwaywest', 'switzerlandnorth', 'switzerlandwest', 'germanynorth', 'germanywestcentral', 'uaenorth', 'uaecentral', 'southafricanorth', 'southafricawest', 'brazilsouth', 'brazilus', 'koreacentral', 'koreasouth', 'koreasouth', 'australiacentral', 'australiacentral2', 'australiaeast', 'australiasoutheast', 'canadacentral', 'canadaeast', 'centralindia', 'eastasia', 'eastus', 'eastus2', 'eastus2euap', 'francecentral', 'francesouth', 'germanywestcentral', 'japaneast', 'japanwest', 'northcentralus', 'northeurope', 'southafricanorth', 'southcentralus', 'southeastasia', 'switzerlandnorth', 'switzerlandwest', 'uksouth', 'ukwest', 'westcentralus', 'westeurope', 'westindia', 'westus', 'westus2')]
    [string]$AzLocation
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

# Create a new Azure Resource Group
az group create `
    --name $AzResourceGroupName `
	--location $AzLocation
