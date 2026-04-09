<#
.SYNOPSIS
    Creates a new virtual network in an Azure environment.

.DESCRIPTION
    This script creates a new virtual network in an Azure environment with the specified parameters.
    Uses the New-AzVirtualNetwork cmdlet from the Az.Network module.

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

.PARAMETER EdgeZone
    The edge zone for the virtual network.

.EXAMPLE
    PS C:\> .\New-AzVirtualNetwork.ps1 -Name "MyVNet" -ResourceGroup "MyResourceGroup" -Location "eastus" -AddressPrefix "10.0.0.0/16"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.Network

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.network/new-azvirtualnetwork?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage = "The name of the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the Azure Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the virtual network will be created.")]
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

    [Parameter(Mandatory=$true, HelpMessage = "The address prefix (CIDR notation) for the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [string]$AddressPrefix,

    [Parameter(Mandatory=$false, HelpMessage = "The DNS server addresses for the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [string]$DnsServer,

    [Parameter(Mandatory=$false, HelpMessage = "The flow timeout value in minutes (3-30).")]
    [ValidateNotNullOrEmpty()]
    [ValidateRange(3, 30)]
    [int]$FlowTimeout,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[PSSubnet[]]$Subnet,

    [Parameter(Mandatory=$false, HelpMessage = "The BGP community value for the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [string]$BgpCommunity,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if encryption is enabled for the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'false',
        'true'
    )]
    [string]$EnableEncryption,

    [Parameter(Mandatory=$false, HelpMessage = "The encryption enforcement policy for the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'allowUnencrypted',
        'dropUnencrypted'
    )]
    [string]$EncryptionEnforcementPolicy,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if DDoS protection is enabled for the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableDdosProtection,

    [Parameter(Mandatory=$false, HelpMessage = "The DDoS protection plan resource ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$DdosProtectionPlanId,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[PSIpAllocation[]]$IpAllocation,

    [Parameter(Mandatory=$false, HelpMessage = "The edge zone for the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroup
    Location          = $Location
    AddressPrefix     = $AddressPrefix
}

if ($DnsServer) {
    $parameters['DnsServer'] = $DnsServer
}

if ($FlowTimeout) {
    $parameters['FlowTimeout'] = $FlowTimeout
}

if ($BgpCommunity) {
    $parameters['BgpCommunity'] = $BgpCommunity
}

if ($EnableEncryption) {
    $parameters['EnableEncryption'] = $EnableEncryption
}

if ($EncryptionEnforcementPolicy) {
    $parameters['EncryptionEnforcementPolicy'] = $EncryptionEnforcementPolicy
}

if ($Tags) {
    $parameters['Tag'] = $Tags
}

if ($EnableDdosProtection) {
    $parameters['EnableDdosProtection'] = $EnableDdosProtection
}

if ($DdosProtectionPlanId) {
    $parameters['DdosProtectionPlanId'] = $DdosProtectionPlanId
}

#if ($IpAllocation) {
#    $parameters['IpAllocation'] = $IpAllocation
#}

if ($EdgeZone) {
    $parameters['EdgeZone'] = $EdgeZone
}

try {
    # Create the virtual network and capture the result
    $result = New-AzVirtualNetwork @parameters

    # Output the result
    Write-Host "✅ Virtual network created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
