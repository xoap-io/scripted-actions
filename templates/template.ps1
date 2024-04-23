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
    PowerShell, Azure CLI, AWS Cli, Azure PowerShell

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [ValidateRange(1024,49151)]
    [string]$AZOpenPorts = '3389',
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmSize,
    [Parameter(Mandatory)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$AzVmUserName,
    [Parameter(Mandatory)]
    [securestring]$AzVmUserPassword,
    [Parameter(Mandatory)]
    [ValidateSet("Flexible", "Uniform")]
    [string]$AzOrchestrationMode = 'Flexible',
    [ValidateSet('Premium_LRS', 'Premium_ZRS', 'Standard_GRS', 'Standard_GZRS', 'Standard_LRS', 'Standard_RAGRS', 'Standard_RAGZRS', 'Standard_ZRS')]
    [string]$AzStorageSku,
    [Parameter(Mandatory)]
    [int]$AzVmCount = 1,
    [Parameter(Mandatory)]
    [datetime]$AzVmExpirationDate,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty]
    [switch]$AzVmAutoShutdown,
    [Parameter(Mandatory=$False)]
    [bool]$BooleanParameter=$False,
    [Parameter(Mandatory)]
    [ValidateNotNull()]
    [int]$AzSubnetCount,
    [parameter(Position = 0, Mandatory)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path,
    [Parameter(Mandatory=$false)]
    [hashtable]$hashTableParam
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

# Add your code here...
