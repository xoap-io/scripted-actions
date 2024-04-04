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
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AZOpenPorts = '3389',
    [Parameter(Mandatory)]
    [string]$AzVmSize
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az vm create `
    --resource-group $MY_RESOURCE_GROUP_NAME `
    --name $MY_VM_NAME `
    --image $MY_VM_IMAGE `
    --admin-username $MY_USERNAME `
    --assign-identity `
    --generate-ssh-keys `
    --public-ip-sku Standard
