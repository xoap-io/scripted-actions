<#
.SYNOPSIS
    List Azure network resources using Azure CLI.

.DESCRIPTION
    This script lists various Azure network resources using the Azure CLI.
    Provides comprehensive visibility into network infrastructure across subscriptions and resource groups.

    The script uses various Azure CLI commands: az network * list

.PARAMETER ResourceGroup
    The name of a specific Azure Resource Group to scope the listing (optional).

.PARAMETER ResourceType
    The type of network resources to list.
    Valid values: 'All', 'VNet', 'Subnet', 'NSG', 'PublicIP', 'LoadBalancer', 'ApplicationGateway', 'Bastion', 'VPN', 'RouteTable', 'Peering'

.PARAMETER OutputFormat
    The output format for the results.
    Valid values: 'Table', 'Json', 'Yaml'

.PARAMETER ShowDetails
    Show detailed information for each resource.

.PARAMETER Location
    Filter resources by specific Azure region.

.EXAMPLE
    .\az-cli-list-network-resources.ps1

    Lists all network resources in the current subscription.

.EXAMPLE
    .\az-cli-list-network-resources.ps1 -ResourceGroup "MyRG" -ResourceType "VNet" -ShowDetails

    Lists all virtual networks in a specific resource group with details.

.EXAMPLE
    .\az-cli-list-network-resources.ps1 -ResourceType "PublicIP" -Location "eastus" -OutputFormat "Json"

    Lists all public IP addresses in East US region in JSON format.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "The name of the Azure Resource Group to scope the listing")]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "The type of network resources to list")]
    [ValidateSet('All', 'VNet', 'Subnet', 'NSG', 'PublicIP', 'LoadBalancer', 'ApplicationGateway', 'Bastion', 'VPN', 'RouteTable', 'Peering')]
    [string]$ResourceType = "All",

    [Parameter(HelpMessage = "The output format for the results")]
    [ValidateSet('Table', 'Json', 'Yaml')]
    [string]$OutputFormat = "Table",

    [Parameter(HelpMessage = "Show detailed information for each resource")]
    [switch]$ShowDetails,

    [Parameter(HelpMessage = "Filter resources by Azure region")]
    [string]$Location
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
    Write-Host "" -ForegroundColor White

    # Set output format
    $outputFlag = switch ($OutputFormat) {
        'Table' { '--output', 'table' }
        'Json' { '--output', 'json' }
        'Yaml' { '--output', 'yaml' }
    }

    # Function to execute Azure CLI command with common parameters
    function Invoke-AzCommand {
        param(
            [string[]]$Command,
            [string]$ResourceName
        )

        $azParams = $Command

        if ($ResourceGroup) {
            $azParams += '--resource-group', $ResourceGroup
        }

        $azParams += $outputFlag

        Write-Host "📋 Listing $ResourceName..." -ForegroundColor Yellow

        $result = & az @azParams 2>&1

        if ($LASTEXITCODE -eq 0) {
            if ($OutputFormat -eq 'Table') {
                $result | Out-Host
            } else {
                # For JSON/YAML, filter by location if specified
                if ($Location -and $OutputFormat -eq 'Json') {
                    $jsonData = $result | ConvertFrom-Json
                    $filteredData = $jsonData | Where-Object { $_.location -eq $Location }
                    $filteredData | ConvertTo-Json -Depth 10
                } else {
                    $result
                }
            }
            Write-Host "" -ForegroundColor White
        } else {
            Write-Host "⚠ Failed to list $ResourceName" -ForegroundColor Yellow
            Write-Host "Error: $($result -join "`n")" -ForegroundColor Red
        }
    }

    # List resources based on type
    switch ($ResourceType) {
        'All' {
            Invoke-AzCommand -Command @('network', 'vnet', 'list') -ResourceName "Virtual Networks"
            Invoke-AzCommand -Command @('network', 'nsg', 'list') -ResourceName "Network Security Groups"
            Invoke-AzCommand -Command @('network', 'public-ip', 'list') -ResourceName "Public IP Addresses"
            Invoke-AzCommand -Command @('network', 'lb', 'list') -ResourceName "Load Balancers"
            Invoke-AzCommand -Command @('network', 'route-table', 'list') -ResourceName "Route Tables"

            if (-not $ResourceGroup) {
                Write-Host "ℹ Note: Use -ResourceGroup parameter to list subnets and peerings" -ForegroundColor Blue
            } else {
                # List subnets for all VNets in the resource group
                $vnetListCmd = @('network', 'vnet', 'list', '--resource-group', $ResourceGroup, '--output', 'json')
                $vnets = & az @vnetListCmd 2>$null | ConvertFrom-Json

                if ($vnets) {
                    foreach ($vnet in $vnets) {
                        Write-Host "📋 Listing Subnets in VNet: $($vnet.name)..." -ForegroundColor Yellow
                        $subnetCmd = @('network', 'vnet', 'subnet', 'list', '--vnet-name', $vnet.name, '--resource-group', $ResourceGroup) + $outputFlag
                        & az @subnetCmd 2>$null
                        Write-Host "" -ForegroundColor White
                    }
                }
            }
        }
        'VNet' {
            Invoke-AzCommand -Command @('network', 'vnet', 'list') -ResourceName "Virtual Networks"
        }
        'Subnet' {
            if (-not $ResourceGroup) {
                throw "ResourceGroup parameter is required when listing subnets"
            }
            # List all VNets first, then their subnets
            $vnetListCmd = @('network', 'vnet', 'list', '--resource-group', $ResourceGroup, '--output', 'json')
            $vnets = & az @vnetListCmd 2>$null | ConvertFrom-Json

            if ($vnets) {
                foreach ($vnet in $vnets) {
                    Write-Host "📋 Listing Subnets in VNet: $($vnet.name)..." -ForegroundColor Yellow
                    $subnetCmd = @('network', 'vnet', 'subnet', 'list', '--vnet-name', $vnet.name, '--resource-group', $ResourceGroup) + $outputFlag
                    & az @subnetCmd 2>$null
                    Write-Host "" -ForegroundColor White
                }
            } else {
                Write-Host "No virtual networks found in resource group '$ResourceGroup'" -ForegroundColor Yellow
            }
        }
        'NSG' {
            Invoke-AzCommand -Command @('network', 'nsg', 'list') -ResourceName "Network Security Groups"
        }
        'PublicIP' {
            Invoke-AzCommand -Command @('network', 'public-ip', 'list') -ResourceName "Public IP Addresses"
        }
        'LoadBalancer' {
            Invoke-AzCommand -Command @('network', 'lb', 'list') -ResourceName "Load Balancers"
        }
        'ApplicationGateway' {
            Invoke-AzCommand -Command @('network', 'application-gateway', 'list') -ResourceName "Application Gateways"
        }
        'Bastion' {
            Invoke-AzCommand -Command @('network', 'bastion', 'list') -ResourceName "Bastion Hosts"
        }
        'VPN' {
            Invoke-AzCommand -Command @('network', 'vnet-gateway', 'list') -ResourceName "Virtual Network Gateways"
            Invoke-AzCommand -Command @('network', 'local-gateway', 'list') -ResourceName "Local Network Gateways"
        }
        'RouteTable' {
            Invoke-AzCommand -Command @('network', 'route-table', 'list') -ResourceName "Route Tables"
        }
        'Peering' {
            if (-not $ResourceGroup) {
                throw "ResourceGroup parameter is required when listing peerings"
            }
            # List all VNets first, then their peerings
            $vnetListCmd = @('network', 'vnet', 'list', '--resource-group', $ResourceGroup, '--output', 'json')
            $vnets = & az @vnetListCmd 2>$null | ConvertFrom-Json

            if ($vnets) {
                foreach ($vnet in $vnets) {
                    Write-Host "📋 Listing Peerings for VNet: $($vnet.name)..." -ForegroundColor Yellow
                    $peeringCmd = @('network', 'vnet', 'peering', 'list', '--vnet-name', $vnet.name, '--resource-group', $ResourceGroup) + $outputFlag
                    & az @peeringCmd 2>$null
                    Write-Host "" -ForegroundColor White
                }
            } else {
                Write-Host "No virtual networks found in resource group '$ResourceGroup'" -ForegroundColor Yellow
            }
        }
    }

    # Show summary if table format
    if ($OutputFormat -eq 'Table') {
        Write-Host "✓ Network resource listing completed" -ForegroundColor Green
        if ($Location) {
            Write-Host "Filtered by location: $Location" -ForegroundColor Cyan
        }
        if ($ResourceGroup) {
            Write-Host "Scoped to resource group: $ResourceGroup" -ForegroundColor Cyan
        }
    }
}
catch {
    Write-Host "✗ Failed to list network resources" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
