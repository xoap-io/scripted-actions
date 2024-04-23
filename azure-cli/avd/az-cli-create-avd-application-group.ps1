<#
.SYNOPSIS
    This script creates an Azure Application Group for an Azure Host Pool.

.DESCRIPTION
    This script creates an Azure Application Group for an Azure Host Pool.
    The script uses the following Azure CLI command:
    az desktopvirtualization applicationgroup create --resource-group $AzResourceGroupName --name $AzApplicationGroupName --host-pool-arm-path $AzHostPoolArmPath --application-group-type $AzHostPoolType

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

.PARAMETER AzApplicationGroupName
    Defines the name of the Azure Application Group.

.PARAMETER AzHostPoolArmPath
    Defines the ARM path of the Azure Host Pool.

.PARAMETER AzHostPoolType
    Defines the type of the Azure Host Pool.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzApplicationGroupName = "myApplicationGroup",
    [Parameter(Mandatory)]
    [string]$AzHostPoolArmPath = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.DesktopVirtualization/hostPools/myHostPool",
    [Parameter(Mandatory)]
    [ValidateSet('Desktop', 'RemoteApp')]
    [string]$AzHostPoolType
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

az desktopvirtualization applicationgroup create `
    --resource-group $AzResourceGroupName `
    --name $AzApplicationGroupName `
    --host-pool-arm-path $AzHostPoolArmPath `
    --application-group-type $AzHostPoolType
