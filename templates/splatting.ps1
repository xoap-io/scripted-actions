<#
.SYNOPSIS
    Creates a new Windows Virtual Desktop (WVD) Host Pool in a specified Azure Resource Group.

.DESCRIPTION
    This script creates a new Windows Virtual Desktop (WVD) Host Pool in a specified Azure Resource Group and location.
    The user must provide the Resource Group name, Host Pool name, and a valid Azure region for the location.
    The script allows additional configurations for the Host Pool, such as host pool type, load balancer type, preferred application group type, etc.
    The script will validate the parameters, execute the creation command, and handle any errors that occur during the process.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the Host Pool will be created. This parameter is mandatory.

.PARAMETER HostPoolName
    The name of the Host Pool to be created. This parameter is mandatory.

.PARAMETER Location
    The Azure region where the Host Pool will be created. This parameter is mandatory and must be one of the predefined valid Azure regions.

.PARAMETER HostPoolType
    The type of host pool to create. Possible values are 'Personal' or 'Pooled'. This parameter is optional and defaults to 'Pooled'.

.PARAMETER LoadBalancerType
    The type of load balancing to use. Possible values are 'BreadthFirst' or 'DepthFirst'. This parameter is optional and defaults to 'BreadthFirst'.

.PARAMETER PreferredAppGroupType
    The preferred application group type for the Host Pool. Possible values are 'Desktop' or 'None'. This parameter is optional and defaults to 'Desktop'.

.PARAMETER MaxSessionLimit
    The maximum number of sessions that can be hosted on a single session host. This parameter is optional.

.PARAMETER CustomRdpProperty
    Custom RDP properties to be applied to the Host Pool. This parameter is optional.

.PARAMETER StartVMOnConnect
    Specifies whether to start the VM on connect. This parameter is optional and defaults to $false.

.PARAMETER FriendlyName
    A friendly name for the Host Pool. This parameter is optional.

.PARAMETER Description
    A description for the Host Pool. This parameter is optional.

.PARAMETER Tags
    A hashtable of tags to apply to the Host Pool. This parameter is optional.

.EXAMPLE
    .\New-WvdHostPool.ps1 -ResourceGroup "MyResourceGroup" -HostPoolName "MyHostPool" -Location "eastus" -HostPoolType "Pooled"

    This command creates a new WVD Host Pool named 'MyHostPool' in the 'MyResourceGroup' Resource Group located in the 'eastus' region with the 'Pooled' host pool type.

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Az.DesktopVirtualization module

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdhostpool

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]   
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2', 'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus', 'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral', 'italynorth', 'norwayeast', 'polandcentral',
        'switzerlandnorth', 'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral', 'asia', 'asiapacific', 'australia',
        'brazil', 'canada', 'europe', 'france', 'global', 'india', 'japan', 'korea', 'norway', 'singapore', 'southafrica',
        'sweden', 'switzerland', 'unitedstates', 'northcentralus', 'westus', 'japanwest', 'centraluseuap', 'eastus2euap',
        'westcentralus', 'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast', 'koreasouth',
        'southindia', 'westindia', 'canadaeast', 'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest', 'ukwest',
        'uaecentral', 'brazilsoutheast'
    )]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Personal', 'Pooled')]
    [string]$HostPoolType = 'Pooled',

    [Parameter(Mandatory = $false)]
    [ValidateSet('BreadthFirst', 'DepthFirst')]
    [string]$LoadBalancerType = 'BreadthFirst',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Desktop', 'None')]
    [string]$PreferredAppGroupType = 'Desktop',

    [Parameter(Mandatory = $false)]
    [int]$MaxSessionLimit,

    [Parameter(Mandatory = $false)]
    [string]$CustomRdpProperty,

    [Parameter(Mandatory = $false)]
    [bool]$StartVMOnConnect = $false,

    [Parameter(Mandatory = $false)]
    [string]$FriendlyName,

    [Parameter(Mandatory = $false)]
    [string]$Description,

    [Parameter(Mandatory = $false)]
    [hashtable]$Tags
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

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
    Tags                   = $Tags
}

try {
    # Start creating the Host Pool
    Write-Output "Creating Host Pool '$HostPoolName' in Resource Group '$ResourceGroup' at Location '$Location'..."
    $hostPool = New-AzWvdHostPool @Parameters
    Write-Output "Host Pool '$HostPoolName' created successfully in '$Location'."
    $hostPool

} catch {
    Write-Error "An error occurred while creating the Host Pool: $($_.Exception.Message)"
    Write-Error "Stack Trace: $($_.Exception.StackTrace)"
}
