<#
.SYNOPSIS
    Create an Azure Virtual Network with subnet using Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Network with a subnet using the Azure CLI.
    Supports advanced features like DDoS protection, encryption, BGP communities, and custom DNS servers.
    
    The script uses the Azure CLI command: az network vnet create

.PARAMETER Name
    The name of the Azure Virtual Network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the VNet will be created.

.PARAMETER AddressPrefixes
    The address prefixes for the virtual network (e.g., '10.0.0.0/16', '192.168.0.0/16').

.PARAMETER Location
    The Azure region where the virtual network will be created.

.PARAMETER SubnetName
    The name of the default subnet to create within the virtual network.

.PARAMETER SubnetPrefixes
    The address prefixes for the subnet (e.g., '10.0.1.0/24').

.PARAMETER DdosProtection
    Enable DDoS protection for the virtual network.

.PARAMETER DdosProtectionPlan
    The resource ID of the DDoS protection plan to associate with the virtual network.

.PARAMETER EnableEncryption
    Enable virtual network encryption for enhanced security.

.PARAMETER EncryptionEnforcementPolicy
    The encryption enforcement policy for the virtual network.
    Valid values: 'AllowUnencrypted', 'DropUnencrypted'

.PARAMETER BgpCommunity
    The BGP community value for the virtual network (used in ExpressRoute scenarios).

.PARAMETER DnsServers
    Custom DNS servers for the virtual network (space-separated list of IP addresses).

.PARAMETER NetworkSecurityGroup
    The name or resource ID of an existing network security group to associate with the subnet.

.PARAMETER VmProtection
    Enable VM protection (DDoS) for the virtual network.

.PARAMETER EdgeZone
    The edge zone name where the virtual network will be created.

.PARAMETER Flowtimeout
    The flow timeout value in minutes (4-30).

.PARAMETER Tags
    Tags to apply to the virtual network in the format 'key1=value1 key2=value2'.

.PARAMETER NoWait
    Do not wait for the operation to complete (asynchronous execution).

.EXAMPLE
    .\az-cli-create-virtual-network.ps1 -Name "MyVNet" -ResourceGroup "MyRG" -AddressPrefixes "10.0.0.0/16" -Location "eastus" -SubnetName "default" -SubnetPrefixes "10.0.1.0/24"
    
    Creates a basic virtual network with a default subnet.

.EXAMPLE
    .\az-cli-create-virtual-network.ps1 -Name "SecureVNet" -ResourceGroup "MyRG" -AddressPrefixes "192.168.0.0/16" -Location "westus2" -SubnetName "web-subnet" -SubnetPrefixes "192.168.1.0/24" -DdosProtection -EnableEncryption -Tags "environment=production tier=web"
    
    Creates a secure virtual network with DDoS protection and encryption enabled.

.EXAMPLE
    .\az-cli-create-virtual-network.ps1 -Name "CustomVNet" -ResourceGroup "MyRG" -AddressPrefixes "172.16.0.0/12" -Location "eastus2" -SubnetName "app-subnet" -SubnetPrefixes "172.16.1.0/24" -DnsServers "8.8.8.8 8.8.4.4" -EncryptionEnforcementPolicy "DropUnencrypted"
    
    Creates a virtual network with custom DNS servers and strict encryption policy.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-overview

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(2, 64)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-\.]{0,62}[a-zA-Z0-9]$|^[a-zA-Z0-9]$', ErrorMessage = "VNet name must be 2-64 characters, start and end with alphanumeric, contain only letters, numbers, hyphens, and periods")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The address prefixes for the virtual network")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$', ErrorMessage = "Address prefix must be in CIDR format (e.g., 10.0.0.0/16)")]
    [string]$AddressPrefixes,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the VNet will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the default subnet")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [string]$SubnetName,

    [Parameter(Mandatory = $true, HelpMessage = "The address prefixes for the subnet")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$', ErrorMessage = "Subnet prefix must be in CIDR format (e.g., 10.0.1.0/24)")]
    [string]$SubnetPrefixes,

    [Parameter(HelpMessage = "Enable DDoS protection for the virtual network")]
    [switch]$DdosProtection,

    [Parameter(HelpMessage = "The resource ID of the DDoS protection plan")]
    [string]$DdosProtectionPlan,

    [Parameter(HelpMessage = "Enable virtual network encryption")]
    [switch]$EnableEncryption,

    [Parameter(HelpMessage = "The encryption enforcement policy")]
    [ValidateSet('AllowUnencrypted', 'DropUnencrypted')]
    [string]$EncryptionEnforcementPolicy,

    [Parameter(HelpMessage = "The BGP community value for ExpressRoute scenarios")]
    [ValidatePattern('^\d+:\d+$', ErrorMessage = "BGP community must be in format 'ASN:value' (e.g., 65515:100)")]
    [string]$BgpCommunity,

    [Parameter(HelpMessage = "Custom DNS servers (space-separated IP addresses)")]
    [string]$DnsServers,

    [Parameter(HelpMessage = "Network security group name or resource ID")]
    [string]$NetworkSecurityGroup,

    [Parameter(HelpMessage = "Enable VM protection (DDoS) for the virtual network")]
    [switch]$VmProtection,

    [Parameter(HelpMessage = "The edge zone name")]
    [string]$EdgeZone,

    [Parameter(HelpMessage = "Flow timeout value in minutes (4-30)")]
    [ValidateRange(4, 30)]
    [int]$Flowtimeout,

    [Parameter(HelpMessage = "Tags in the format 'key1=value1 key2=value2'")]
    [string]$Tags,

    [Parameter(HelpMessage = "Do not wait for the operation to complete")]
    [switch]$NoWait
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    # Check if Azure CLI is available
    if (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not found in PATH. Please install Azure CLI first."
    }

    # Check if user is logged in to Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }

    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'vnet', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--address-prefixes', $AddressPrefixes,
        '--location', $Location,
        '--subnet-name', $SubnetName,
        '--subnet-prefixes', $SubnetPrefixes
    )

    # Add optional parameters
    if ($DdosProtection) { 
        $azParams += '--ddos-protection', 'true' 
    }
    if ($DdosProtectionPlan) { 
        $azParams += '--ddos-protection-plan', $DdosProtectionPlan 
    }
    if ($EnableEncryption) { 
        $azParams += '--enable-encryption', 'true' 
    }
    if ($EncryptionEnforcementPolicy) { 
        $azParams += '--encryption-enforcement-policy', $EncryptionEnforcementPolicy 
    }
    if ($BgpCommunity) { 
        $azParams += '--bgp-community', $BgpCommunity 
    }
    if ($DnsServers) { 
        $azParams += '--dns-servers', $DnsServers 
    }
    if ($NetworkSecurityGroup) { 
        $azParams += '--network-security-group', $NetworkSecurityGroup 
    }
    if ($VmProtection) { 
        $azParams += '--vm-protection', 'true' 
    }
    if ($EdgeZone) { 
        $azParams += '--edge-zone', $EdgeZone 
    }
    if ($Flowtimeout) { 
        $azParams += '--flowtimeout', $Flowtimeout 
    }
    if ($Tags) { 
        $azParams += '--tags', $Tags 
    }
    if ($NoWait) { 
        $azParams += '--no-wait' 
    }

    Write-Host "Creating Azure Virtual Network..." -ForegroundColor Yellow
    Write-Host "VNet Name: $Name" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan
    Write-Host "Address Prefixes: $AddressPrefixes" -ForegroundColor Cyan
    Write-Host "Subnet Name: $SubnetName" -ForegroundColor Cyan
    Write-Host "Subnet Prefixes: $SubnetPrefixes" -ForegroundColor Cyan

    if ($DdosProtection) {
        Write-Host "DDoS Protection: Enabled" -ForegroundColor Green
    }
    if ($EnableEncryption) {
        Write-Host "Encryption: Enabled" -ForegroundColor Green
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        if ($NoWait) {
            Write-Host "✓ Virtual Network creation started (asynchronous)" -ForegroundColor Green
        }
        else {
            Write-Host "✓ Azure Virtual Network created successfully!" -ForegroundColor Green
            
            # Parse and display VNet information
            try {
                $vnetInfo = $result | ConvertFrom-Json
                Write-Host "VNet Details:" -ForegroundColor Cyan
                Write-Host "  Name: $($vnetInfo.name)" -ForegroundColor White
                Write-Host "  Resource Group: $($vnetInfo.resourceGroup)" -ForegroundColor White
                Write-Host "  Location: $($vnetInfo.location)" -ForegroundColor White
                Write-Host "  Address Space: $($vnetInfo.addressSpace.addressPrefixes -join ', ')" -ForegroundColor White
                
                if ($vnetInfo.subnets -and $vnetInfo.subnets.Count -gt 0) {
                    Write-Host "  Subnets:" -ForegroundColor White
                    foreach ($subnet in $vnetInfo.subnets) {
                        Write-Host "    - $($subnet.name): $($subnet.addressPrefix)" -ForegroundColor White
                    }
                }
                
                if ($vnetInfo.enableDdosProtection) {
                    Write-Host "  DDoS Protection: Enabled" -ForegroundColor Green
                }
                if ($vnetInfo.encryption -and $vnetInfo.encryption.enabled) {
                    Write-Host "  Encryption: Enabled" -ForegroundColor Green
                }
                if ($vnetInfo.dhcpOptions -and $vnetInfo.dhcpOptions.dnsServers) {
                    Write-Host "  Custom DNS: $($vnetInfo.dhcpOptions.dnsServers -join ', ')" -ForegroundColor White
                }
            }
            catch {
                Write-Host "VNet created successfully, but could not parse detailed information." -ForegroundColor Yellow
            }
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Azure Virtual Network" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
