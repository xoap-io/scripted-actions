<#
.SYNOPSIS
    Create a new Azure Virtual Desktop workspace with the Azure PowerShell.

.DESCRIPTION
    The New-AzWvdWorkspace cmdlet creates a new Azure Virtual Desktop workspace.

    The cmdlet requires the following parameters:
    - AzResourceGroupName: Defines the name of the Azure Resource Group.
    - AzWorkspaceName: Defines the name of the Azure Virtual Desktop workspace.
    - AzLocation: Defines the location of the Azure Virtual Desktop workspace.
    - AzFriendlyName: Defines the friendly name of the Azure Virtual Desktop workspace.
    - AzApplicationGroupName: Defines the name of the Azure Virtual Desktop application group.
    - AzDescription: Defines the description of the Azure Virtual Desktop workspace.

    The cmdlet will create a new Azure Virtual Desktop workspace with the provided parameters.    

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
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzWorkspaceName
    Defines the name of the Azure Virtual Desktop workspace.

.PARAMETER AzLocation
    Defines the location of the Azure Virtual Desktop workspace.

.PARAMETER AzFriendlyName
    Defines the friendly name of the Azure Virtual Desktop workspace.

.PARAMETER AzApplicationGroupName
    Defines the name of the Azure Virtual Desktop application group.

.PARAMETER AzDescription
    Defines the description of the Azure Virtual Desktop workspace.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzWorkspaceName,
    [Parameter(Mandatory)]
    [string]$AzLocation,
    [Parameter(Mandatory)]
    [string]$AzFriendlyName,
    [Parameter(Mandatory)]
    [string]$AzApplicationGroupName,
    [Parameter(Mandatory)]
    [string]$AzDescription
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

New-AzWvdWorkspace -ResourceGroupName $AzResourceGroupName `
    -Name $AzWorkspaceName `
    -Location $AzLocation `
    -FriendlyName $AzFriendlyName `
    -ApplicationGroupReference "/subscriptions/$AzSubscription/resourceGroups/$AzResourceGroupName/providers/Microsoft.DesktopVirtualization/applicationGroups/$AzApplicationGroupName" `
    -Description $AzDescription
