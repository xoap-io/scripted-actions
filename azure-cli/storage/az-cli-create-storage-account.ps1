<#
.SYNOPSIS
    Create a new Azure Storage Account with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Storage Account with the Azure CLI.
    The script uses the following Azure CLI command:
    az storage account create --name $AzStorageAccountName --resource-group $AzResourceGroupName --location $AzLocation --sku $AzStorageSku

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

.PARAMETER AzStorageAccountName
    Defines the name of the Azure Storage Account.

.PARAMETER AzStorageSku
    Defines the SKU of the Azure Storage Account.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzLocation,
    [Parameter(Mandatory)]
    [string]$AzStorageAccountName,
    [Parameter(Mandatory)]
    [ValidateSet('Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS')]
    [string]$AzStorageSku
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az storage account create `
    --name $AzStorageAccountName `
    --resource-group $AzResourceGroupName `
    --location $AzLocation `
    --sku $AzStorageSku
