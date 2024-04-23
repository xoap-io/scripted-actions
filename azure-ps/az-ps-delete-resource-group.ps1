<#
.SYNOPSIS
    This script deletes an Azure Resource Group with the Azure PowerShell.

.DESCRIPTION
    This script deletes an Azure Resource Group with the Azure PowerShell. The script requires the following parameter:
    - AzResourceGroupName: Defines the name of the Azure Resource Group.

    The script will delete the Azure Resource Group with all its resources.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    Azure PowerShell

.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

Remove-AzResourceGroup `
    -Name $AzResourceGroupName `
    -Force
