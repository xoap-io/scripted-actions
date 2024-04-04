<#
.SYNOPSIS
    This script creates an Azure Virtual Desktop workspace.

.DESCRIPTION
    This script creates an Azure Virtual Desktop workspace.
    The script uses the following Azure CLI command:
    az desktopvirtualization workspace create --resource-group rg --name workspace-name --friendly-name friendly

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

.PARAMETER AzWorkspaceName
    Defines the name of the Azure Virtual Desktop workspace.

.PARAMETER AzWorkspaceFrindlyName
    Defines the friendly name of the Azure Virtual Desktop workspace.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzWorkspaceName,
    [Parameter(Mandatory)]
    [string]$AzWorkspaceFrindlyName
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az desktopvirtualization workspace create `
    --resource-group $AzResourceGroupName `
    --name $AzWorkspaceName `
    --friendly-name $AzWorkspaceFrindlyName `
    