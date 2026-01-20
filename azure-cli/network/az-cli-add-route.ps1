<#
.SYNOPSIS
    Add a route to an Azure Route Table using Azure CLI.

.DESCRIPTION
    This script adds a custom route to an existing Azure Route Table using the Azure CLI.
    Custom routes override Azure's default system routes and control how traffic is routed from subnets.

    The script uses the Azure CLI command: az network route-table route create

.PARAMETER RouteTableName
    The name of the existing Route Table.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the Route Table.

.PARAMETER RouteName
    The name of the route to create.

.PARAMETER AddressPrefix
    The destination address prefix in CIDR format (e.g., '10.1.0.0/16', '0.0.0.0/0').

.PARAMETER NextHopType
    The type of Azure hop the packet should be sent to.
    Valid values: 'VirtualNetworkGateway', 'VnetLocal', 'Internet', 'VirtualAppliance', 'None'

.PARAMETER NextHopIpAddress
    The IP address of the next hop (required when NextHopType is 'VirtualAppliance').

.EXAMPLE
    .\az-cli-add-route.ps1 -RouteTableName "app-routes" -ResourceGroup "MyRG" -RouteName "ToInternet" -AddressPrefix "0.0.0.0/0" -NextHopType "Internet"

    Creates a default route to the internet.

.EXAMPLE
    .\az-cli-add-route.ps1 -RouteTableName "secure-routes" -ResourceGroup "MyRG" -RouteName "ToFirewall" -AddressPrefix "10.1.0.0/16" -NextHopType "VirtualAppliance" -NextHopIpAddress "10.0.1.4"

    Creates a route through a network virtual appliance (like a firewall).

.EXAMPLE
    .\az-cli-add-route.ps1 -RouteTableName "hub-routes" -ResourceGroup "MyRG" -RouteName "ToOnPrem" -AddressPrefix "192.168.0.0/16" -NextHopType "VirtualNetworkGateway"

    Creates a route to on-premises networks through a VPN/ExpressRoute gateway.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/route-table/route

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the existing Route Table")]
    [ValidateNotNullOrEmpty()]
    [string]$RouteTableName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the route")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [string]$RouteName,

    [Parameter(Mandatory = $true, HelpMessage = "The destination address prefix in CIDR format")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$', ErrorMessage = "Address prefix must be in CIDR format (e.g., 10.1.0.0/16 or 0.0.0.0/0)")]
    [string]$AddressPrefix,

    [Parameter(Mandatory = $true, HelpMessage = "The type of Azure hop the packet should be sent to")]
    [ValidateSet('VirtualNetworkGateway', 'VnetLocal', 'Internet', 'VirtualAppliance', 'None')]
    [string]$NextHopType,

    [Parameter(HelpMessage = "The IP address of the next hop (required for VirtualAppliance)")]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$', ErrorMessage = "Next hop IP must be a valid IPv4 address")]
    [string]$NextHopIpAddress
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

    # Verify the Route Table exists
    Write-Host "Verifying Route Table exists..." -ForegroundColor Yellow
    $rtCheck = az network route-table show --name $RouteTableName --resource-group $ResourceGroup 2>$null
    if (-not $rtCheck) {
        throw "Route Table '$RouteTableName' not found in resource group '$ResourceGroup'"
    }
    Write-Host "✓ Route Table '$RouteTableName' found" -ForegroundColor Green

    # Validate NextHopIpAddress requirement
    if ($NextHopType -eq 'VirtualAppliance' -and -not $NextHopIpAddress) {
        throw "NextHopIpAddress is required when NextHopType is 'VirtualAppliance'"
    }
    if ($NextHopType -ne 'VirtualAppliance' -and $NextHopIpAddress) {
        Write-Host "⚠ Warning: NextHopIpAddress is only used with VirtualAppliance next hop type" -ForegroundColor Yellow
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'route-table', 'route', 'create',
        '--route-table-name', $RouteTableName,
        '--resource-group', $ResourceGroup,
        '--name', $RouteName,
        '--address-prefix', $AddressPrefix,
        '--next-hop-type', $NextHopType
    )

    # Add next hop IP address if specified
    if ($NextHopIpAddress) {
        $azParams += '--next-hop-ip-address', $NextHopIpAddress
    }

    Write-Host "Creating route in Route Table..." -ForegroundColor Yellow
    Write-Host "Route Table: $RouteTableName" -ForegroundColor Cyan
    Write-Host "Route Name: $RouteName" -ForegroundColor Cyan
    Write-Host "Address Prefix: $AddressPrefix" -ForegroundColor Cyan
    Write-Host "Next Hop Type: $NextHopType" -ForegroundColor Cyan

    if ($NextHopIpAddress) {
        Write-Host "Next Hop IP: $NextHopIpAddress" -ForegroundColor Cyan
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Route created successfully!" -ForegroundColor Green

        # Parse and display route information
        try {
            $routeInfo = $result | ConvertFrom-Json
            Write-Host "Route Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($routeInfo.name)" -ForegroundColor White
            Write-Host "  Address Prefix: $($routeInfo.addressPrefix)" -ForegroundColor White
            Write-Host "  Next Hop Type: $($routeInfo.nextHopType)" -ForegroundColor White

            if ($routeInfo.nextHopIpAddress) {
                Write-Host "  Next Hop IP: $($routeInfo.nextHopIpAddress)" -ForegroundColor White
            }

            Write-Host "  Provisioning State: $($routeInfo.provisioningState)" -ForegroundColor White

            # Provide helpful information about route types
            switch ($routeInfo.nextHopType) {
                'Internet' {
                    Write-Host "  ℹ This route directs traffic to the internet" -ForegroundColor Blue
                }
                'VirtualNetworkGateway' {
                    Write-Host "  ℹ This route directs traffic through VPN/ExpressRoute gateway" -ForegroundColor Blue
                }
                'VirtualAppliance' {
                    Write-Host "  ℹ This route directs traffic through a network virtual appliance" -ForegroundColor Blue
                }
                'VnetLocal' {
                    Write-Host "  ℹ This route keeps traffic within the virtual network" -ForegroundColor Blue
                }
                'None' {
                    Write-Host "  ℹ This route drops traffic (black hole route)" -ForegroundColor Blue
                }
            }
        }
        catch {
            Write-Host "Route created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create route" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
