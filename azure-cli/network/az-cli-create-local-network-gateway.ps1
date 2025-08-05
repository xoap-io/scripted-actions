<#
.SYNOPSIS
    Create an Azure Local Network Gateway using Azure CLI.

.DESCRIPTION
    This script creates a Local Network Gateway in Azure using the Azure CLI.
    Local Network Gateways represent on-premises network endpoints for VPN connections.
    Used to establish site-to-site VPN connections between Azure and on-premises networks.
    
    The script uses the Azure CLI command: az network local-gateway create

.PARAMETER GatewayName
    The name of the Local Network Gateway to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the Local Network Gateway will be created.

.PARAMETER Location
    The Azure region where the Local Network Gateway will be deployed.

.PARAMETER GatewayIPAddress
    The public IP address of the on-premises VPN device.

.PARAMETER AddressPrefixes
    The address spaces of the on-premises network (comma-separated CIDR blocks).

.PARAMETER EnableBGP
    Enable Border Gateway Protocol (BGP) for dynamic routing.

.PARAMETER BGPPeerIP
    The BGP peer IP address on the on-premises device.

.PARAMETER ASN
    The Autonomous System Number (ASN) for the on-premises BGP router.

.PARAMETER BGPPeerWeight
    The weight added to routes learned from this BGP peer.

.PARAMETER Tags
    Tags to apply to the Local Network Gateway as JSON string.

.EXAMPLE
    .\az-cli-create-local-network-gateway.ps1 -GatewayName "onprem-lgw" -ResourceGroup "network-rg" -Location "East US" -GatewayIPAddress "203.0.113.10" -AddressPrefixes "192.168.0.0/16,10.0.0.0/8"
    
    Creates a Local Network Gateway for on-premises networks with static routing.

.EXAMPLE
    .\az-cli-create-local-network-gateway.ps1 -GatewayName "onprem-lgw-bgp" -ResourceGroup "network-rg" -Location "East US" -GatewayIPAddress "203.0.113.10" -AddressPrefixes "192.168.1.0/24" -EnableBGP -BGPPeerIP "192.168.1.1" -ASN 65001
    
    Creates a Local Network Gateway with BGP enabled for dynamic routing.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: Used in conjunction with VPN Gateways to create site-to-site connections.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/local-gateway

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Local Network Gateway")]
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

    [Parameter(Mandatory = $true, HelpMessage = "The public IP address of the on-premises VPN device")]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$')]
    [string]$GatewayIPAddress,

    [Parameter(Mandatory = $true, HelpMessage = "Comma-separated list of on-premises address prefixes (CIDR)")]
    [ValidateNotNullOrEmpty()]
    [string]$AddressPrefixes,

    [Parameter(HelpMessage = "Enable Border Gateway Protocol (BGP)")]
    [switch]$EnableBGP,

    [Parameter(HelpMessage = "The BGP peer IP address")]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$')]
    [string]$BGPPeerIP,

    [Parameter(HelpMessage = "The Autonomous System Number (ASN)")]
    [ValidateRange(1, 4294967295)]
    [int]$ASN = 65001,

    [Parameter(HelpMessage = "BGP peer weight for route preference")]
    [ValidateRange(0, 100)]
    [int]$BGPPeerWeight = 0,

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

    # Check if Local Network Gateway already exists
    Write-Host "Checking if Local Network Gateway already exists..." -ForegroundColor Yellow
    $existingLGW = az network local-gateway show --name $GatewayName --resource-group $ResourceGroup 2>$null
    if ($existingLGW) {
        throw "Local Network Gateway '$GatewayName' already exists in resource group '$ResourceGroup'"
    }
    Write-Host "✓ Local Network Gateway name is available" -ForegroundColor Green

    # Validate address prefixes format
    Write-Host "Validating address prefixes..." -ForegroundColor Yellow
    $prefixArray = $AddressPrefixes -split ',' | ForEach-Object { $_.Trim() }
    foreach ($prefix in $prefixArray) {
        if ($prefix -notmatch '^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$') {
            throw "Invalid CIDR format: '$prefix'. Expected format: x.x.x.x/xx"
        }
    }
    Write-Host "✓ Address prefixes validated" -ForegroundColor Green

    # Validate BGP configuration
    if ($EnableBGP) {
        if (-not $BGPPeerIP) {
            throw "BGP peer IP address is required when BGP is enabled"
        }
        Write-Host "✓ BGP configuration validated" -ForegroundColor Green
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'local-gateway', 'create',
        '--name', $GatewayName,
        '--resource-group', $ResourceGroup,
        '--location', $Location,
        '--gateway-ip-address', $GatewayIPAddress,
        '--local-address-prefixes'
    )
    
    # Add address prefixes as separate arguments
    $azParams += $prefixArray

    # Add BGP configuration if enabled
    if ($EnableBGP) {
        $azParams += '--asn', $ASN.ToString()
        $azParams += '--bgp-peering-address', $BGPPeerIP
        if ($BGPPeerWeight -gt 0) {
            $azParams += '--peer-weight', $BGPPeerWeight.ToString()
        }
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
    Write-Host "Local Network Gateway Configuration:" -ForegroundColor Cyan
    Write-Host "  Name: $GatewayName" -ForegroundColor White
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "  Location: $Location" -ForegroundColor White
    Write-Host "  Gateway IP: $GatewayIPAddress" -ForegroundColor White
    Write-Host "  Address Prefixes:" -ForegroundColor White
    foreach ($prefix in $prefixArray) {
        Write-Host "    • $prefix" -ForegroundColor White
    }
    
    if ($EnableBGP) {
        Write-Host "  BGP: Enabled" -ForegroundColor Green
        Write-Host "    ASN: $ASN" -ForegroundColor White
        Write-Host "    Peer IP: $BGPPeerIP" -ForegroundColor White
        if ($BGPPeerWeight -gt 0) {
            Write-Host "    Peer Weight: $BGPPeerWeight" -ForegroundColor White
        }
    } else {
        Write-Host "  BGP: Disabled (Static Routing)" -ForegroundColor White
    }

    Write-Host "Creating Local Network Gateway..." -ForegroundColor Yellow

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $lgwInfo = $result | ConvertFrom-Json
        
        Write-Host "✓ Local Network Gateway created successfully!" -ForegroundColor Green
        Write-Host "Local Network Gateway Details:" -ForegroundColor Cyan
        Write-Host "  Name: $($lgwInfo.name)" -ForegroundColor White
        Write-Host "  Resource ID: $($lgwInfo.id)" -ForegroundColor White
        Write-Host "  Provisioning State: $($lgwInfo.provisioningState)" -ForegroundColor White
        Write-Host "  Gateway IP Address: $($lgwInfo.gatewayIpAddress)" -ForegroundColor White
        
        Write-Host "  Local Network Address Spaces:" -ForegroundColor White
        foreach ($space in $lgwInfo.localNetworkAddressSpace.addressPrefixes) {
            Write-Host "    • $space" -ForegroundColor White
        }
        
        if ($lgwInfo.bgpSettings) {
            Write-Host "  BGP Configuration:" -ForegroundColor Green
            Write-Host "    ASN: $($lgwInfo.bgpSettings.asn)" -ForegroundColor White
            Write-Host "    BGP Peering Address: $($lgwInfo.bgpSettings.bgpPeeringAddress)" -ForegroundColor White
            if ($lgwInfo.bgpSettings.peerWeight) {
                Write-Host "    Peer Weight: $($lgwInfo.bgpSettings.peerWeight)" -ForegroundColor White
            }
        }
        
        Write-Host "" -ForegroundColor White
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "• Create a VPN connection between this Local Network Gateway and your VPN Gateway" -ForegroundColor White
        Write-Host "• Configure your on-premises VPN device with the Azure VPN Gateway's public IP" -ForegroundColor White
        Write-Host "• Set up the shared key (pre-shared key) for the VPN connection" -ForegroundColor White
        if ($EnableBGP) {
            Write-Host "• Configure BGP on your on-premises router to peer with Azure" -ForegroundColor White
        } else {
            Write-Host "• Configure static routes on your on-premises device" -ForegroundColor White
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Local Network Gateway" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
