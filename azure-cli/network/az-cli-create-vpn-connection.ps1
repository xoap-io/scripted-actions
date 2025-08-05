<#
.SYNOPSIS
    Create a VPN connection between Azure VPN Gateway and Local Network Gateway using Azure CLI.

.DESCRIPTION
    This script creates a VPN connection between an Azure VPN Gateway and a Local Network Gateway using the Azure CLI.
    Supports both IPSec/IKE site-to-site connections and BGP-enabled connections.
    Configures shared keys, connection protocols, and routing preferences.
    
    The script uses the Azure CLI command: az network vpn-connection create

.PARAMETER ConnectionName
    The name of the VPN connection to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the VPN connection will be created.

.PARAMETER Location
    The Azure region where the VPN connection will be deployed.

.PARAMETER VPNGatewayName
    The name of the Azure VPN Gateway.

.PARAMETER LocalGatewayName
    The name of the Local Network Gateway representing the on-premises network.

.PARAMETER SharedKey
    The shared key (pre-shared key) for the VPN connection.

.PARAMETER ConnectionType
    The type of VPN connection to create.

.PARAMETER EnableBGP
    Enable Border Gateway Protocol (BGP) for dynamic routing.

.PARAMETER RoutingWeight
    The routing weight for this connection.

.PARAMETER IKEv2Protocol
    Use IKEv2 protocol for the connection.

.PARAMETER UseLocalAzureIPAddress
    Use local Azure IP address for the connection.

.PARAMETER Tags
    Tags to apply to the VPN connection as JSON string.

.EXAMPLE
    .\az-cli-create-vpn-connection.ps1 -ConnectionName "azure-to-onprem" -ResourceGroup "network-rg" -Location "East US" -VPNGatewayName "azure-vpn-gw" -LocalGatewayName "onprem-lgw" -SharedKey "MySecureKey123!"
    
    Creates a basic site-to-site VPN connection.

.EXAMPLE
    .\az-cli-create-vpn-connection.ps1 -ConnectionName "azure-to-onprem-bgp" -ResourceGroup "network-rg" -Location "East US" -VPNGatewayName "azure-vpn-gw" -LocalGatewayName "onprem-lgw-bgp" -SharedKey "MySecureKey123!" -EnableBGP -RoutingWeight 100
    
    Creates a VPN connection with BGP enabled and custom routing weight.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: Both VPN Gateway and Local Network Gateway must exist before creating the connection.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vpn-connection

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the VPN connection")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [string]$ConnectionName,

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure VPN Gateway")]
    [ValidateNotNullOrEmpty()]
    [string]$VPNGatewayName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Local Network Gateway")]
    [ValidateNotNullOrEmpty()]
    [string]$LocalGatewayName,

    [Parameter(Mandatory = $true, HelpMessage = "The shared key for the VPN connection")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(8, 128)]
    [string]$SharedKey,

    [Parameter(HelpMessage = "The type of VPN connection")]
    [ValidateSet("IPsec", "Vnet2Vnet", "ExpressRoute")]
    [string]$ConnectionType = "IPsec",

    [Parameter(HelpMessage = "Enable Border Gateway Protocol (BGP)")]
    [switch]$EnableBGP,

    [Parameter(HelpMessage = "The routing weight for this connection")]
    [ValidateRange(0, 32000)]
    [int]$RoutingWeight = 10,

    [Parameter(HelpMessage = "Use IKEv2 protocol")]
    [switch]$IKEv2Protocol,

    [Parameter(HelpMessage = "Use local Azure IP address")]
    [switch]$UseLocalAzureIPAddress,

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

    # Check if VPN connection already exists
    Write-Host "Checking if VPN connection already exists..." -ForegroundColor Yellow
    $existingConnection = az network vpn-connection show --name $ConnectionName --resource-group $ResourceGroup 2>$null
    if ($existingConnection) {
        throw "VPN connection '$ConnectionName' already exists in resource group '$ResourceGroup'"
    }
    Write-Host "✓ VPN connection name is available" -ForegroundColor Green

    # Verify VPN Gateway exists
    Write-Host "Verifying VPN Gateway exists..." -ForegroundColor Yellow
    $vpnGwCheck = az network vnet-gateway show --name $VPNGatewayName --resource-group $ResourceGroup 2>$null
    if (-not $vpnGwCheck) {
        throw "VPN Gateway '$VPNGatewayName' not found in resource group '$ResourceGroup'"
    }
    $vpnGwInfo = $vpnGwCheck | ConvertFrom-Json
    Write-Host "✓ VPN Gateway '$VPNGatewayName' found" -ForegroundColor Green

    # Verify Local Network Gateway exists
    Write-Host "Verifying Local Network Gateway exists..." -ForegroundColor Yellow
    $localGwCheck = az network local-gateway show --name $LocalGatewayName --resource-group $ResourceGroup 2>$null
    if (-not $localGwCheck) {
        throw "Local Network Gateway '$LocalGatewayName' not found in resource group '$ResourceGroup'"
    }
    $localGwInfo = $localGwCheck | ConvertFrom-Json
    Write-Host "✓ Local Network Gateway '$LocalGatewayName' found" -ForegroundColor Green

    # Validate BGP compatibility
    if ($EnableBGP) {
        if (-not $vpnGwInfo.enableBgp) {
            Write-Host "⚠ Warning: VPN Gateway does not have BGP enabled. BGP will be disabled for this connection." -ForegroundColor Yellow
            $EnableBGP = $false
        } elseif (-not $localGwInfo.bgpSettings) {
            Write-Host "⚠ Warning: Local Network Gateway does not have BGP configured. BGP will be disabled for this connection." -ForegroundColor Yellow
            $EnableBGP = $false
        } else {
            Write-Host "✓ BGP compatibility verified" -ForegroundColor Green
        }
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'vpn-connection', 'create',
        '--name', $ConnectionName,
        '--resource-group', $ResourceGroup,
        '--location', $Location,
        '--vnet-gateway1', $VPNGatewayName,
        '--local-gateway2', $LocalGatewayName,
        '--shared-key', $SharedKey,
        '--connection-type', $ConnectionType
    )

    # Add BGP configuration if enabled and compatible
    if ($EnableBGP) {
        $azParams += '--enable-bgp', 'true'
    }

    # Add routing weight
    if ($RoutingWeight -ne 10) {
        $azParams += '--routing-weight', $RoutingWeight.ToString()
    }

    # Add IKEv2 protocol if specified
    if ($IKEv2Protocol) {
        $azParams += '--use-policy-based-traffic-selectors', 'false'
    }

    # Add local Azure IP address option
    if ($UseLocalAzureIPAddress) {
        $azParams += '--use-local-azure-ip-address', 'true'
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
    Write-Host "VPN Connection Configuration:" -ForegroundColor Cyan
    Write-Host "  Connection Name: $ConnectionName" -ForegroundColor White
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "  Location: $Location" -ForegroundColor White
    Write-Host "  Connection Type: $ConnectionType" -ForegroundColor White
    Write-Host "  VPN Gateway: $VPNGatewayName" -ForegroundColor White
    Write-Host "  Local Gateway: $LocalGatewayName" -ForegroundColor White
    Write-Host "  Shared Key: [Protected]" -ForegroundColor White
    Write-Host "  Routing Weight: $RoutingWeight" -ForegroundColor White
    
    if ($EnableBGP) {
        Write-Host "  BGP: Enabled" -ForegroundColor Green
        Write-Host "    Azure ASN: $($vpnGwInfo.bgpSettings.asn)" -ForegroundColor White
        Write-Host "    On-premises ASN: $($localGwInfo.bgpSettings.asn)" -ForegroundColor White
    } else {
        Write-Host "  BGP: Disabled (Static Routing)" -ForegroundColor White
    }
    
    if ($IKEv2Protocol) {
        Write-Host "  Protocol: IKEv2" -ForegroundColor White
    }

    # Display network information
    Write-Host "Network Information:" -ForegroundColor Cyan
    Write-Host "  Azure Gateway IP: $($vpnGwInfo.ipConfigurations[0].publicIPAddress.id -split '/')[-1]" -ForegroundColor White
    Write-Host "  On-premises Gateway IP: $($localGwInfo.gatewayIpAddress)" -ForegroundColor White
    Write-Host "  On-premises Networks:" -ForegroundColor White
    foreach ($prefix in $localGwInfo.localNetworkAddressSpace.addressPrefixes) {
        Write-Host "    • $prefix" -ForegroundColor White
    }

    Write-Host "Creating VPN connection..." -ForegroundColor Yellow
    Write-Host "⚠ This may take 5-10 minutes to complete" -ForegroundColor Yellow

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        $connectionInfo = $result | ConvertFrom-Json
        
        Write-Host "✓ VPN connection created successfully!" -ForegroundColor Green
        Write-Host "VPN Connection Details:" -ForegroundColor Cyan
        Write-Host "  Name: $($connectionInfo.name)" -ForegroundColor White
        Write-Host "  Resource ID: $($connectionInfo.id)" -ForegroundColor White
        Write-Host "  Provisioning State: $($connectionInfo.provisioningState)" -ForegroundColor White
        Write-Host "  Connection Status: $($connectionInfo.connectionStatus)" -ForegroundColor White
        Write-Host "  Connection Type: $($connectionInfo.connectionType)" -ForegroundColor White
        
        if ($connectionInfo.enableBgp) {
            Write-Host "  BGP: Enabled" -ForegroundColor Green
        } else {
            Write-Host "  BGP: Disabled" -ForegroundColor White
        }
        
        Write-Host "" -ForegroundColor White
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "• Configure your on-premises VPN device with these settings:" -ForegroundColor White
        Write-Host "  - Azure Gateway IP: Check the VPN Gateway's public IP" -ForegroundColor White
        Write-Host "  - Shared Key: $SharedKey" -ForegroundColor White
        Write-Host "  - Connection Type: $ConnectionType" -ForegroundColor White
        if ($EnableBGP) {
            Write-Host "  - Configure BGP peering with Azure" -ForegroundColor White
        } else {
            Write-Host "  - Configure static routes to Azure VNet subnets" -ForegroundColor White
        }
        Write-Host "• Test connectivity once both ends are configured" -ForegroundColor White
        Write-Host "• Monitor connection status in Azure portal" -ForegroundColor White
        
        Write-Host "" -ForegroundColor White
        Write-Host "To check connection status:" -ForegroundColor Cyan
        Write-Host "az network vpn-connection show --name $ConnectionName --resource-group $ResourceGroup --query 'connectionStatus'" -ForegroundColor White
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create VPN connection" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
