<#
.SYNOPSIS
    Disconnect a user session from an Azure Virtual Desktop host pool.

.DESCRIPTION
    This script disconnects a user session from an Azure Virtual Desktop host pool. The script uses the Azure PowerShell module and the Disconnect-AzWvdUserSession cmdlet.
    The script disconnects a user session from an Azure Virtual Desktop host pool. The script requires the following parameters:
    - AzResourceGroupName: The name of the Azure Resource Group.
    - AzHostPoolName: The name of the Azure Virtual Desktop host pool.
    - AzSessionHostName: The name of the session host.
    - AzSessionId: The ID of the user session.

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
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzHostPoolName
    Defines the name of the Azure Virtual Desktop host pool.

.PARAMETER AzSessionHostName
    Defines the name of the session host.

.PARAMETER AzSessionId
    Defines the ID of the user session.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = 'myResourceGroup',
    [Parameter(Mandatory)]
    [string]$AzHostPoolName = 'myHostPool',
    [Parameter(Mandatory)]
    [string]$AzSessionHostName = 'mySessionHostName',
    [Parameter(Mandatory)]
    [string]$AzSessionId = 'mySessionId'
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

Disconnect-AzWvdUserSession `
    -ResourceGroupName $AzResourceGroupName `
    -HostPoolName $AzHostPoolName `
    -SessionHostName $AzSessionHostName `
    -Id $AzSessionId
