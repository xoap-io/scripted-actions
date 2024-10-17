<#
.SYNOPSIS
    Create an Azure Virtual Network and Subnet.

.DESCRIPTION
    This script creates an Azure Virtual Network and Subnet.
    The script uses the following Azure CLI command:
    az network vnet create --name $AzVnetName --resource-group $AzResourceGroupName --address-prefixes $AzVnetAddressPrefix --subnet-name $AzSubnetName --subnet-prefixes $AzSubnetAddressPrefix

.PARAMETER Name
    The name of the Azure Virtual Network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER AddressPrefixes
    The address prefixes of the Azure Virtual Network.

.PARAMETER BgpCommunity
    The BGP community of the Azure Virtual Network.

.PARAMETER DdosProtection
    The DDoS protection of the Azure Virtual Network.

.PARAMETER DdosProtectionPlan
    The DDoS protection plan of the Azure Virtual Network.

.PARAMETER DnsServers
    The DNS servers of the Azure Virtual Network.

.PARAMETER EdgeZone
    The edge zone of the Azure Virtual Network.

.PARAMETER EnableEncryption
    The encryption status of the Azure Virtual Network.

.PARAMETER EncryptionEnforcementPolicy
    The encryption enforcement policy of the Azure Virtual Network.

.PARAMETER Flowtimeout
    The flow timeout of the Azure Virtual Network.

.PARAMETER Location
    The location of the Azure Virtual Network.

.PARAMETER NetworkSecurityGroup
    The network security group of the Azure Virtual Network.

.PARAMETER NoWait
    The no-wait status of the Azure Virtual Network.

.PARAMETER SubnetName
    The name of the Azure Virtual Network subnet.

.PARAMETER SubnetPrefixes
    The address prefixes of the Azure Virtual Network subnet.

.PARAMETER Subnets
    The subnets of the Azure Virtual Network.

.PARAMETER Tags
    The tags of the Azure Virtual Network.

.PARAMETER VmProtection
    The VM protection of the Azure Virtual Network.

.PARAMETER VnetPrefixes
    The address prefixes of the Azure Virtual Network.

.PARAMETER VnetType
    The type of the Azure Virtual Network.

.PARAMETER Zones
    The zones of the Azure Virtual Network.

.EXAMPLE
    .\az-cli-create-virtual-network.ps1 -AzVnetName "MyVNet" -AzResourceGroupName "MyResourceGroup" -AzVnetAddressPrefix "10.0.0.0/16" -AzSubnetName "MySubnet" -AzSubnetAddressPrefix "10.0.1.0/24"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
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
    [string]$AddressPrefixes,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$BgpCommunity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DdosProtection,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DdosProtectionPlan,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DnsServers,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableEncryption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionEnforcementPolicy,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Flowtimeout,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NetworkSecurityGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NoWait,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetPrefixes,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Subnets,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VmProtection,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VnetPrefixes,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VnetType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Zones
)

# Splatting parameters for better readability
$parameters = @{
    '--name' = $Name
    '--resource-group' = $ResourceGroup
}

if ($AddressPrefixes) {
    $parameters += '--address-prefixes', $AddressPrefixes
}

if ($BgpCommunity) {
    $parameters += '--bgp-community', $BgpCommunity
}

if ($DdosProtection) {
    $parameters += '--ddos-protection', $DdosProtection
}

if ($DdosProtectionPlan) {
    $parameters += '--ddos-protection-plan', $DdosProtectionPlan
}

if ($DnsServers) {
    $parameters += '--dns-servers', $DnsServers
}

if ($EdgeZone) {
    $parameters += '--edge-zone', $EdgeZone
}

if ($EnableEncryption) {
    $parameters += '--enable-encryption', $EnableEncryption
}

if ($EncryptionEnforcementPolicy) {
    $parameters += '--encryption-enforcement-policy', $EncryptionEnforcementPolicy
}

if ($Flowtimeout) {
    $parameters += '--flowtimeout', $Flowtimeout
}

if ($Location) {
    $parameters += '--location', $Location
}

if ($NetworkSecurityGroup) {
    $parameters += '--network-security-group', $NetworkSecurityGroup
}

if ($NoWait) {
    $parameters += '--no-wait', $NoWait
}

if ($SubnetName) {
    $parameters += '--subnet-name', $SubnetName
}

if ($SubnetPrefixes) {
    $parameters += '--subnet-prefixes', $SubnetPrefixes
}

if ($Subnets) {
    $parameters += '--subnets', $Subnets
}

if ($Tags) {
    $parameters += '--tags', $Tags
}

if ($VmProtection) {
    $parameters += '--vm-protection', $VmProtection
}

if ($VnetPrefixes) {
    $parameters += '--vnet-prefixes', $VnetPrefixes
}

if ($VnetType) {
    $parameters += '--vnet-type', $VnetType
}

if ($Zones) {
    $parameters += '--zones', $Zones
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create a virtual network and subnet
    az network vnet create @parameters

    # Output the result
    Write-Output "Azure Virtual Network and Subnet created successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Virtual Network and Subnet: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
