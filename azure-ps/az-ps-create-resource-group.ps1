<#
.SYNOPSIS
    Create a new Azure Resource Group with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure Resource Group with the Azure PowerShell.
    The script uses the following Azure PowerShell command:
    New-AzResourceGroup -Name $AzResourceGroupName -Location $AzLocation

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
    Azure PowerShell

.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzLocation
    Defines the location of the Azure VM.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [ValidateSet('eastus', 'eastus2', 'germany', 'northeurope', 'germanywestcentral')]
    [string]$AzLocation
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

New-AzResourceGroup `
	-Name $AzResourceGroupName `
	-Location $AzLocation
