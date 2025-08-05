<#
.SYNOPSIS
    Create an Azure VPN Gateway using Azure CLI.

.DESCRIPTION
    This script creates an Azure VPN Gateway using the Azure CLI.
    Supports both Route-based and Policy-based VPN types with various SKUs and features.
    Includes options for active-active configuration, BGP, and point-to-site VPN.
    
    The script uses the Azure CLI command: az network vnet-gateway create

.PARAMETER GatewayName
    The name of the VPN Gateway to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the VPN Gateway will be created.

.PARAMETER Location
    The Azure region where the VPN Gateway will be deployed.

.PARAMETER VNetName
    The name of the Virtual Network where the VPN Gateway will be deployed.

.PARAMETER GatewaySubnetName
    The name of the gateway subnet (typically 'GatewaySubnet').

.PARAMETER PublicIPName
    The name of the public IP address to associate with the VPN Gateway.

.PARAMETER PublicIPName2
    The name of the second public IP address for active-active configuration.

.PARAMETER GatewayType
    The type of gateway to create.

.PARAMETER VPNType
    The VPN routing type.

.PARAMETER SKU
    The SKU (performance tier) of the VPN Gateway.

.PARAMETER Generation
    The generation of the VPN Gateway.

.PARAMETER EnableActiveActive
    Enable active-active configuration (requires two public IPs).

.PARAMETER EnableBGP
    Enable Border Gateway Protocol (BGP) for dynamic routing.

.PARAMETER ASN
    The Autonomous System Number (ASN) for BGP.

.PARAMETER EnableP2S
    Enable Point-to-Site VPN configuration.

.PARAMETER P2SAddressPool
    The address pool for Point-to-Site VPN clients.

.PARAMETER Tags
    Tags to apply to the VPN Gateway as JSON string.

.EXAMPLE
    .\az-cli-create-vpn-gateway.ps1 -GatewayName "hub-vpn-gw" -ResourceGroup "network-rg" -Location "East US" -VNetName "hub-vnet" -PublicIPName "vpn-gw-pip"
    
    Creates a basic VPN Gateway with default settings.

.EXAMPLE
    .\az-cli-create-vpn-gateway.ps1 -GatewayName "prod-vpn-gw" -ResourceGroup "network-rg" -Location "East US" -VNetName "prod-vnet" -PublicIPName "vpn-gw-pip1" -PublicIPName2 "vpn-gw-pip2" -SKU "VpnGw1" -EnableActiveActive -EnableBGP -ASN 65001
    
    Creates a VPN Gateway with active-active configuration and BGP enabled.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: VPN Gateway creation can take 45-60 minutes. Requires a dedicated GatewaySubnet.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet-gateway

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the VPN Gateway")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [string]$GatewayName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region for deployment")]
    [ValidateSet(
        "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "North Central US", "South Central US",
        "Canada Central", "Canada East", "Brazil South", "North Europe", "West Europe", "UK South", "UK West",
        "France Central", "Germany West Central", "Switzerland North", "Norway East", "Sweden Central",
        "Australia East", "Australia Southeast", "Southeast Asia", "East Asia", "Japan East", "Japan West",
        "Korea Central", "Central India", "South India", "West India", "UAE North", "South Africa North"
    )]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [string]$VNetName,

    [Parameter(HelpMessage = "The name of the gateway subnet")]
    [ValidateNotNullOrEmpty()]
    [string]$GatewaySubnetName = "GatewaySubnet",

    [Parameter(Mandatory = $true, HelpMessage = "The name of the primary public IP address")]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIPName,

    [Parameter(HelpMessage = "The name of the second public IP address for active-active configuration")]
    [string]$PublicIPName2,

    [Parameter(HelpMessage = "The type of gateway")]
    [ValidateSet("Vpn", "ExpressRoute")]
    [string]$GatewayType = "Vpn",

    [Parameter(HelpMessage = "The VPN routing type")]
    [ValidateSet("RouteBased", "PolicyBased")]
    [string]$VPNType = "RouteBased",

    [Parameter(HelpMessage = "The SKU of the VPN Gateway")]
    [ValidateSet("Basic", "Standard", "HighPerformance", "UltraPerformance", "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5", "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ")]
    [string]$SKU = "VpnGw1",

    [Parameter(HelpMessage = "The generation of the VPN Gateway")]
    [ValidateSet("Generation1", "Generation2")]
    [string]$Generation = "Generation1",

    [Parameter(HelpMessage = "Enable active-active configuration")]
    [switch]$EnableActiveActive,

    [Parameter(HelpMessage = "Enable Border Gateway Protocol (BGP)")]
    [switch]$EnableBGP,

    [Parameter(HelpMessage = "The Autonomous System Number (ASN) for BGP")]
    [ValidateRange(1, 4294967295)]
    [int]$ASN = 65515,

    [Parameter(HelpMessage = "Enable Point-to-Site VPN configuration")]
    [switch]$EnableP2S,

    [Parameter(HelpMessage = "The address pool for Point-to-Site VPN clients")]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$P2SAddressPool = "172.16.200.0/24",

    [Parameter(HelpMessage = "Tags as JSON string")]
    [string]$Tags
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

    # Check if resource group exists
    Write-Host "Verifying resource group exists..." -ForegroundColor Yellow
    $rgExists = az group show --name $ResourceGroup 2>$null
    if (-not $rgExists) {
        throw "Resource group '$ResourceGroup' not found. Please create it first or specify an existing resource group."
    }
    Write-Host "✓ Resource group '$ResourceGroup' found" -ForegroundColor Green

    # Check if VPN Gateway already exists
    Write-Host "Checking if VPN Gateway already exists..." -ForegroundColor Yellow
    $existingGW = az network vnet-gateway show --name $GatewayName --resource-group $ResourceGroup 2>$null
    if ($existingGW) {
        throw "VPN Gateway '$GatewayName' already exists in resource group '$ResourceGroup'"
    }
    Write-Host "✓ VPN Gateway name is available" -ForegroundColor Green

    # Verify VNet and gateway subnet exist
    Write-Host "Verifying Virtual Network and gateway subnet..." -ForegroundColor Yellow
    $vnetCheck = az network vnet show --name $VNetName --resource-group $ResourceGroup 2>$null
    if (-not $vnetCheck) {
        throw "Virtual Network '$VNetName' not found in resource group '$ResourceGroup'"
    }

    $gatewaySubnetCheck = az network vnet subnet show --vnet-name $VNetName --name $GatewaySubnetName --resource-group $ResourceGroup 2>$null
    if (-not $gatewaySubnetCheck) {
        throw "Gateway subnet '$GatewaySubnetName' not found in Virtual Network '$VNetName'. Please create a subnet named 'GatewaySubnet' first."
    }
    Write-Host "✓ Virtual Network and gateway subnet verified" -ForegroundColor Green

    # Verify primary public IP exists
    Write-Host "Verifying public IP address(es)..." -ForegroundColor Yellow
    $pipCheck = az network public-ip show --name $PublicIPName --resource-group $ResourceGroup 2>$null
    if (-not $pipCheck) {
        throw "Public IP '$PublicIPName' not found in resource group '$ResourceGroup'. Please create it first."
    }

    # Verify second public IP if active-active is enabled
    if ($EnableActiveActive) {
        if (-not $PublicIPName2) {
            throw "Active-active configuration requires a second public IP address. Please provide -PublicIPName2 parameter."
        }
        $pip2Check = az network public-ip show --name $PublicIPName2 --resource-group $ResourceGroup 2>$null
        if (-not $pip2Check) {
            throw "Second public IP '$PublicIPName2' not found in resource group '$ResourceGroup'. Please create it first."
        }
        Write-Host "✓ Both public IP addresses verified for active-active configuration" -ForegroundColor Green
    } else {
        Write-Host "✓ Primary public IP address verified" -ForegroundColor Green
    }

    # Validate SKU compatibility
    if ($EnableActiveActive -and $SKU -in @("Basic", "Standard")) {
        throw "Active-active configuration is not supported with Basic or Standard SKUs. Please use VpnGw1 or higher."
    }

    if ($EnableBGP -and $SKU -eq "Basic") {
        throw "BGP is not supported with Basic SKU. Please use Standard or higher."
    }

    # Build basic Azure CLI command parameters
    $azParams = @(
        'network', 'vnet-gateway', 'create',
        '--name', $GatewayName,
        '--resource-group', $ResourceGroup,
        '--location', $Location,
        '--vnet', $VNetName,
        '--gateway-type', $GatewayType,
        '--sku', $SKU,
        '--public-ip-address', $PublicIPName
    )

    # Add VPN-specific parameters
    if ($GatewayType -eq "Vpn") {
        $azParams += '--vpn-type', $VPNType
        if ($Generation -eq "Generation2" -and $SKU -like "VpnGw*") {
            $azParams += '--vpn-gateway-generation', $Generation
        }
    }

    # Add active-active configuration
    if ($EnableActiveActive) {
        $azParams += '--public-ip-address-2', $PublicIPName2
    }

    # Add BGP configuration
    if ($EnableBGP) {
        $azParams += '--asn', $ASN.ToString()
    } else {
        $azParams += '--no-wait'  # Don't wait for completion if BGP is not enabled
    }

    # Add Point-to-Site configuration
    if ($EnableP2S) {
        $azParams += '--address-prefixes', $P2SAddressPool
    }

    # Add tags if provided
    if ($Tags) {
        try {
            # Validate JSON format
            $null = $Tags | ConvertFrom-Json
            $azParams += '--tags', $Tags
        }
        catch {
            Write-Host "⚠ Warning: Invalid JSON format for tags. Skipping tags." -ForegroundColor Yellow
        }
    }

    # Display configuration summary
    Write-Host "VPN Gateway Configuration:" -ForegroundColor Cyan
    Write-Host "  Name: $GatewayName" -ForegroundColor White
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "  Location: $Location" -ForegroundColor White
    Write-Host "  Virtual Network: $VNetName" -ForegroundColor White
    Write-Host "  Gateway Subnet: $GatewaySubnetName" -ForegroundColor White
    Write-Host "  Gateway Type: $GatewayType" -ForegroundColor White
    if ($GatewayType -eq "Vpn") {
        Write-Host "  VPN Type: $VPNType" -ForegroundColor White
        Write-Host "  Generation: $Generation" -ForegroundColor White
    }
    Write-Host "  SKU: $SKU" -ForegroundColor White
    Write-Host "  Primary Public IP: $PublicIPName" -ForegroundColor White
    
    if ($EnableActiveActive) {
        Write-Host "  Secondary Public IP: $PublicIPName2" -ForegroundColor White
        Write-Host "  Active-Active: Enabled" -ForegroundColor White
    } else {
        Write-Host "  Active-Active: Disabled" -ForegroundColor White
    }
    
    if ($EnableBGP) {
        Write-Host "  BGP: Enabled (ASN: $ASN)" -ForegroundColor White
    } else {
        Write-Host "  BGP: Disabled" -ForegroundColor White
    }

    if ($EnableP2S) {
        Write-Host "  Point-to-Site: Enabled (Pool: $P2SAddressPool)" -ForegroundColor White
    } else {
        Write-Host "  Point-to-Site: Disabled" -ForegroundColor White
    }

    Write-Host "Creating VPN Gateway..." -ForegroundColor Yellow
    Write-Host "⚠ This may take 45-60 minutes to complete" -ForegroundColor Yellow
    Write-Host "⚠ The gateway will be created in the background" -ForegroundColor Yellow

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ VPN Gateway creation initiated successfully!" -ForegroundColor Green
        Write-Host "Gateway Name: $GatewayName" -ForegroundColor White
        Write-Host "Resource Group: $ResourceGroup" -ForegroundColor White
        
        Write-Host "" -ForegroundColor White
        Write-Host "⏳ The VPN Gateway is being created in the background." -ForegroundColor Yellow
        Write-Host "This process typically takes 45-60 minutes to complete." -ForegroundColor Yellow
        Write-Host "" -ForegroundColor White
        Write-Host "To check the status, run:" -ForegroundColor Cyan
        Write-Host "az network vnet-gateway show --name $GatewayName --resource-group $ResourceGroup --query 'provisioningState'" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "Next steps after creation completes:" -ForegroundColor Yellow
        Write-Host "• Create local network gateways for site-to-site connections" -ForegroundColor White
        Write-Host "• Configure VPN connections to on-premises networks" -ForegroundColor White
        if ($EnableP2S) {
            Write-Host "• Configure Point-to-Site authentication and client certificates" -ForegroundColor White
        }
        if ($EnableBGP) {
            Write-Host "• Configure BGP peering with on-premises routers" -ForegroundColor White
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create VPN Gateway" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
