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

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateRange(1024,49151)]
    [string]$AZOpenPorts = '3389',

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmSize,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrWhiteSpace()]
    [string]$AzVmUserName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [securestring]$AzVmUserPassword,

    [Parameter(Mandatory=$false)]
    [ValidateSet(
        'Flexible',
        'Uniform'
    )]
    [string]$AzOrchestrationMode = 'Flexible',

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Premium_LRS',
        'Premium_ZRS',
        'Standard_GRS',
        'Standard_GZRS',
        'Standard_LRS',
        'Standard_RAGRS',
        'Standard_RAGZRS',
        'Standard_ZRS'
    )]
    [string]$AzStorageSku,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$AzVmCount = 1,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [datetime]$AzVmExpirationDate,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty]
    [switch]$AzVmAutoShutdown,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty]
    [bool]$BooleanParameter=$False,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty]
    [int]$AzSubnetCount,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path $_ })]
    [string]$Path,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$hashTableParam
)

#Set Error Action to Stop
$ErrorActionPreference =  "Stop"

$Parameters = @{
    ResourceGroup      = $ResourceGroup
    HostPoolName           = $HostPoolName
    Location               = $Location
    HostPoolType           = $HostPoolType
    LoadBalancerType       = $LoadBalancerType
    PreferredAppGroupType  = $PreferredAppGroupType
    MaxSessionLimit        = $MaxSessionLimit
    CustomRdpProperty      = $CustomRdpProperty
    StartVMOnConnect       = $StartVMOnConnect
    FriendlyName           = $FriendlyName
    Description            = $Description
}

if ($Tags) {
    $Tag = $Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } -join '-'
    $parameters['Tag', $Tag
}

# Add your code here...
