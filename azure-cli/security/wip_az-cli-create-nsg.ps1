<#
.SYNOPSIS
    Short description

.DESCRIPTION
    Long description

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT


.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,

)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az network nsg rule create `
    --resource-group $AzResourceGroupName `
    --nsg-name $AzNsgName `
    --name $AzNsgRuleName `
    --priority $AzNsgPriority `
    --source-address-prefixes 208.130.28.0/24 `
    --source-port-ranges 80 `
    --destination-address-prefixes '*' `
    --destination-port-ranges 80 8080 `
    --access Deny `
    --protocol Tcp `
    --description "Deny from specific IP address ranges on 80 and 8080."
