<#
.SYNOPSIS
    Create an Azure Virtual Network subnet using Azure CLI.

.DESCRIPTION
    This script creates a subnet within an existing Azure Virtual Network using the Azure CLI.
    Supports advanced subnet features like service endpoints, delegations, and security configurations.

    The script uses the Azure CLI command: az network vnet subnet create

.PARAMETER VNetName
    The name of the existing Azure Virtual Network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the virtual network.

.PARAMETER SubnetName
    The name of the subnet to create.

.PARAMETER AddressPrefix
    The address prefix for the subnet in CIDR format (e.g., '10.0.1.0/24').

.PARAMETER NetworkSecurityGroup
    The name or resource ID of an existing network security group to associate with the subnet.

.PARAMETER RouteTable
    The name or resource ID of an existing route table to associate with the subnet.

.PARAMETER ServiceEndpoints
    Space-separated list of service endpoints to enable (e.g., 'Microsoft.Storage Microsoft.KeyVault').

.PARAMETER Delegations
    Service delegation for the subnet (e.g., 'Microsoft.Web/serverFarms').

.PARAMETER DisablePrivateEndpointNetworkPolicies
    Disable network policies for private endpoints in this subnet.

.PARAMETER DisablePrivateLinkServiceNetworkPolicies
    Disable network policies for private link services in this subnet.

.PARAMETER NatGateway
    The name or resource ID of a NAT gateway to associate with the subnet.

.EXAMPLE
    .\az-cli-create-subnet.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "web-subnet" -AddressPrefix "10.0.1.0/24"

    Creates a basic subnet in an existing virtual network.

.EXAMPLE
    .\az-cli-create-subnet.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "app-subnet" -AddressPrefix "10.0.2.0/24" -NetworkSecurityGroup "app-nsg" -ServiceEndpoints "Microsoft.Storage Microsoft.KeyVault"

    Creates a subnet with NSG and service endpoints for storage and key vault.

.EXAMPLE
    .\az-cli-create-subnet.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "private-subnet" -AddressPrefix "10.0.3.0/24" -DisablePrivateEndpointNetworkPolicies

    Creates a subnet optimized for private endpoints.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet/subnet

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-subnet

.COMPONENT
    Azure CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the existing Azure Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [string]$VNetName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the subnet to create")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-\.]{0,78}[a-zA-Z0-9]$|^[a-zA-Z0-9]$', ErrorMessage = "Subnet name must be 1-80 characters, start and end with alphanumeric, contain only letters, numbers, hyphens, and periods")]
    [string]$SubnetName,

    [Parameter(Mandatory = $true, HelpMessage = "The address prefix for the subnet")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}\/\d{1,2}$', ErrorMessage = "Address prefix must be in CIDR format (e.g., 10.0.1.0/24)")]
    [string]$AddressPrefix,

    [Parameter(HelpMessage = "Network security group name or resource ID")]
    [string]$NetworkSecurityGroup,

    [Parameter(HelpMessage = "Route table name or resource ID")]
    [string]$RouteTable,

    [Parameter(HelpMessage = "Space-separated list of service endpoints")]
    [string]$ServiceEndpoints,

    [Parameter(HelpMessage = "Service delegation for the subnet")]
    [ValidateSet('Microsoft.Web/serverFarms', 'Microsoft.ContainerInstance/containerGroups', 'Microsoft.Netapp/volumes', 'Microsoft.HardwareSecurityModules/dedicatedHSMs', 'Microsoft.ServiceFabricMesh/networks', 'Microsoft.Logic/integrationServiceEnvironments', 'Microsoft.Batch/batchAccounts', 'Microsoft.Sql/managedInstances')]
    [string]$Delegations,

    [Parameter(HelpMessage = "Disable network policies for private endpoints")]
    [switch]$DisablePrivateEndpointNetworkPolicies,

    [Parameter(HelpMessage = "Disable network policies for private link services")]
    [switch]$DisablePrivateLinkServiceNetworkPolicies,

    [Parameter(HelpMessage = "NAT gateway name or resource ID")]
    [string]$NatGateway
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

    # Verify the VNet exists
    Write-Host "Verifying virtual network exists..." -ForegroundColor Yellow
    $vnetCheck = az network vnet show --name $VNetName --resource-group $ResourceGroup 2>$null
    if (-not $vnetCheck) {
        throw "Virtual network '$VNetName' not found in resource group '$ResourceGroup'"
    }
    Write-Host "✓ Virtual network '$VNetName' found" -ForegroundColor Green

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'vnet', 'subnet', 'create',
        '--vnet-name', $VNetName,
        '--resource-group', $ResourceGroup,
        '--name', $SubnetName,
        '--address-prefix', $AddressPrefix
    )

    # Add optional parameters
    if ($NetworkSecurityGroup) {
        $azParams += '--network-security-group', $NetworkSecurityGroup
    }
    if ($RouteTable) {
        $azParams += '--route-table', $RouteTable
    }
    if ($ServiceEndpoints) {
        $azParams += '--service-endpoints', $ServiceEndpoints
    }
    if ($Delegations) {
        $azParams += '--delegations', $Delegations
    }
    if ($DisablePrivateEndpointNetworkPolicies) {
        $azParams += '--disable-private-endpoint-network-policies', 'true'
    }
    if ($DisablePrivateLinkServiceNetworkPolicies) {
        $azParams += '--disable-private-link-service-network-policies', 'true'
    }
    if ($NatGateway) {
        $azParams += '--nat-gateway', $NatGateway
    }

    Write-Host "Creating subnet in virtual network..." -ForegroundColor Yellow
    Write-Host "VNet Name: $VNetName" -ForegroundColor Cyan
    Write-Host "Subnet Name: $SubnetName" -ForegroundColor Cyan
    Write-Host "Address Prefix: $AddressPrefix" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan

    if ($NetworkSecurityGroup) {
        Write-Host "Network Security Group: $NetworkSecurityGroup" -ForegroundColor Cyan
    }
    if ($ServiceEndpoints) {
        Write-Host "Service Endpoints: $ServiceEndpoints" -ForegroundColor Cyan
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Subnet created successfully!" -ForegroundColor Green

        # Parse and display subnet information
        try {
            $subnetInfo = $result | ConvertFrom-Json
            Write-Host "Subnet Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($subnetInfo.name)" -ForegroundColor White
            Write-Host "  Address Prefix: $($subnetInfo.addressPrefix)" -ForegroundColor White
            Write-Host "  Resource Group: $($subnetInfo.resourceGroup)" -ForegroundColor White

            if ($subnetInfo.networkSecurityGroup) {
                Write-Host "  Network Security Group: $($subnetInfo.networkSecurityGroup.id -split '/')[-1]" -ForegroundColor White
            }
            if ($subnetInfo.routeTable) {
                Write-Host "  Route Table: $($subnetInfo.routeTable.id -split '/')[-1]" -ForegroundColor White
            }
            if ($subnetInfo.serviceEndpoints -and $subnetInfo.serviceEndpoints.Count -gt 0) {
                Write-Host "  Service Endpoints: $($subnetInfo.serviceEndpoints.service -join ', ')" -ForegroundColor White
            }
            if ($subnetInfo.delegations -and $subnetInfo.delegations.Count -gt 0) {
                Write-Host "  Delegations: $($subnetInfo.delegations.serviceName -join ', ')" -ForegroundColor White
            }
        }
        catch {
            Write-Host "Subnet created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
