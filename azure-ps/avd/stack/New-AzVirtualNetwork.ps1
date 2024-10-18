<#
.SYNOPSIS
    Creates a new virtual network in an Azure environment.

.DESCRIPTION
    This script creates a new virtual network in an Azure environment with the specified parameters.

.PARAMETER Name
    The name of the virtual network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Location
    The location of the virtual network.

.PARAMETER AddressPrefix
    The address prefix for the virtual network.

.PARAMETER DnsServer
    The DNS servers for the virtual network.

.PARAMETER FlowTimeout
    The flow timeout for the virtual network.

.PARAMETER Subnet
    The subnets for the virtual network.

.PARAMETER BgpCommunity
    The BGP community for the virtual network.

.PARAMETER EnableEncryption
    Indicates if encryption is enabled for the virtual network.

.PARAMETER EncryptionEnforcementPolicy
    The encryption enforcement policy for the virtual network.

.PARAMETER Tags
    The tags for the virtual network.

.PARAMETER EnableDdosProtection
    Indicates if DDoS protection is enabled for the virtual network.

.PARAMETER DdosProtectionPlanId
    The DDoS protection plan ID for the virtual network.

.PARAMETER IpAllocation
    The IP allocations for the virtual network.

.PARAMETER EdgeZone
    The edge zone for the virtual network.

.EXAMPLE
    PS C:\> .\New-AzVirtualNetwork.ps1 -Name "MyVNet" -AzResourceGroup "MyResourceGroup" -AzLocation "eastus" -AzAddressPrefix "10.0.0.0/16"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.Network

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.network/new-azvirtualnetwork?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral',
        'asia', 'asiapacific', 'australia', 'brazil',
        'canada', 'europe', 'france', 'germany',
        'global', 'india', 'japan', 'korea',
        'norway', 'singapore', 'southafrica', 'sweden',
        'switzerland', 'unitedstates', 'northcentralus', 'westus',
        'japanwest', 'centraluseuap', 'eastus2euap', 'westcentralus',
        'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast',
        'koreasouth', 'southindia', 'westindia', 'canadaeast',
        'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest',
        'ukwest', 'uaecentral', 'brazilsoutheast'
    )]
    [string]$Location,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AddressPrefix,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DnsServer,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateRange(3, 30)]
    [int]$FlowTimeout,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[PSSubnet[]]$Subnet,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$BgpCommunity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'false',
        'true'
    )]
    [string]$EnableEncryption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'allowUnencrypted',
        'dropUnencrypted'
    )]
    [string]$EncryptionEnforcementPolicy,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableDdosProtection,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DdosProtectionPlanId,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[PSIpAllocation[]]$IpAllocation,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone
)

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroup = $ResourceGroup
    Location          = $Location
    AddressPrefix     = $AddressPrefix
}

if ($DnsServer) {
    $parameters['DnsServer'], $DnsServer
}

if ($FlowTimeout) {
    $parameters['FlowTimeout'], $FlowTimeout
}

if ($BgpCommunity) {
    $parameters['BgpCommunity'], $BgpCommunity
}

if ($EnableEncryption) {
    $parameters['EnableEncryption'], $EnableEncryption
}

if ($EncryptionEnforcementPolicy) {
    $parameters['EncryptionEnforcementPolicy'], $EncryptionEnforcementPolicy
}

if ($Tags) {
    $parameters['Tag'], $Tags
}

if ($EnableDdosProtection) {
    $parameters['EnableDdosProtection'], $EnableDdosProtection
}

if ($DdosProtectionPlanId) {
    $parameters['DdosProtectionPlanId'], $DdosProtectionPlanId
}

#if ($IpAllocation) {
#    $parameters['IpAllocation'], $IpAllocation
#}

if ($EdgeZone) {
    $parameters['EdgeZone'], $EdgeZone
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {   
    # Create the virtual network and capture the result
    $result = New-AzVirtualNetwork @parameters

    # Output the result
    Write-Output "Virtual network created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the virtual network: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
