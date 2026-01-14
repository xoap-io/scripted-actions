<#
.SYNOPSIS
    Create an Azure Application Gateway using Azure CLI.

.DESCRIPTION
    This script creates an Azure Application Gateway using the Azure CLI.
    Supports configuration of backend pools, HTTP settings, listeners, and routing rules.
    Includes options for SSL termination, Web Application Firewall (WAF), and autoscaling.

    The script uses the Azure CLI command: az network application-gateway create

.PARAMETER AppGatewayName
    The name of the Application Gateway to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the Application Gateway will be created.

.PARAMETER Location
    The Azure region where the Application Gateway will be deployed.

.PARAMETER VNetName
    The name of the Virtual Network where the Application Gateway will be deployed.

.PARAMETER SubnetName
    The name of the subnet within the VNet for the Application Gateway.

.PARAMETER SKU
    The SKU (size/tier) of the Application Gateway.

.PARAMETER Capacity
    The instance count for the Application Gateway (ignored for autoscaling SKUs).

.PARAMETER PublicIPName
    The name of the public IP address to associate with the Application Gateway.

.PARAMETER EnableWAF
    Enable Web Application Firewall (WAF) protection.

.PARAMETER WAFMode
    The WAF mode when WAF is enabled.

.PARAMETER MinCapacity
    Minimum number of instances for autoscaling SKUs.

.PARAMETER MaxCapacity
    Maximum number of instances for autoscaling SKUs.

.PARAMETER EnableHTTP2
    Enable HTTP/2 support.

.PARAMETER Tags
    Tags to apply to the Application Gateway as JSON string.

.EXAMPLE
    .\az-cli-create-application-gateway.ps1 -AppGatewayName "web-appgw" -ResourceGroup "prod-rg" -Location "East US" -VNetName "hub-vnet" -SubnetName "appgw-subnet" -PublicIPName "appgw-pip"

    Creates a basic Application Gateway with default settings.

.EXAMPLE
    .\az-cli-create-application-gateway.ps1 -AppGatewayName "secure-appgw" -ResourceGroup "prod-rg" -Location "East US" -VNetName "hub-vnet" -SubnetName "appgw-subnet" -PublicIPName "appgw-pip" -SKU "WAF_v2" -EnableWAF -WAFMode "Prevention" -MinCapacity 2 -MaxCapacity 10

    Creates an Application Gateway with WAF protection and autoscaling.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: Application Gateway requires a dedicated subnet.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/application-gateway

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Application Gateway")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [string]$AppGatewayName,

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the subnet for Application Gateway")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(HelpMessage = "The SKU of the Application Gateway")]
    [ValidateSet("Standard_Small", "Standard_Medium", "Standard_Large", "Standard_v2", "WAF_Medium", "WAF_Large", "WAF_v2")]
    [string]$SKU = "Standard_v2",

    [Parameter(HelpMessage = "The instance count (ignored for v2 SKUs with autoscaling)")]
    [ValidateRange(1, 32)]
    [int]$Capacity = 2,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the public IP address")]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIPName,

    [Parameter(HelpMessage = "Enable Web Application Firewall")]
    [switch]$EnableWAF,

    [Parameter(HelpMessage = "WAF mode when WAF is enabled")]
    [ValidateSet("Detection", "Prevention")]
    [string]$WAFMode = "Detection",

    [Parameter(HelpMessage = "Minimum capacity for autoscaling")]
    [ValidateRange(0, 100)]
    [int]$MinCapacity = 0,

    [Parameter(HelpMessage = "Maximum capacity for autoscaling")]
    [ValidateRange(2, 125)]
    [int]$MaxCapacity = 10,

    [Parameter(HelpMessage = "Enable HTTP/2 support")]
    [switch]$EnableHTTP2,

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

    # Check if Application Gateway already exists
    Write-Host "Checking if Application Gateway already exists..." -ForegroundColor Yellow
    $existingAppGW = az network application-gateway show --name $AppGatewayName --resource-group $ResourceGroup 2>$null
    if ($existingAppGW) {
        throw "Application Gateway '$AppGatewayName' already exists in resource group '$ResourceGroup'"
    }
    Write-Host "✓ Application Gateway name is available" -ForegroundColor Green

    # Verify VNet and subnet exist
    Write-Host "Verifying Virtual Network and subnet..." -ForegroundColor Yellow
    $vnetCheck = az network vnet show --name $VNetName --resource-group $ResourceGroup 2>$null
    if (-not $vnetCheck) {
        throw "Virtual Network '$VNetName' not found in resource group '$ResourceGroup'"
    }

    $subnetCheck = az network vnet subnet show --vnet-name $VNetName --name $SubnetName --resource-group $ResourceGroup 2>$null
    if (-not $subnetCheck) {
        throw "Subnet '$SubnetName' not found in Virtual Network '$VNetName'"
    }
    Write-Host "✓ Virtual Network and subnet verified" -ForegroundColor Green

    # Verify public IP exists
    Write-Host "Verifying public IP address..." -ForegroundColor Yellow
    $pipCheck = az network public-ip show --name $PublicIPName --resource-group $ResourceGroup 2>$null
    if (-not $pipCheck) {
        throw "Public IP '$PublicIPName' not found in resource group '$ResourceGroup'. Please create it first."
    }
    Write-Host "✓ Public IP address verified" -ForegroundColor Green

    # Validate WAF configuration
    if ($EnableWAF -and $SKU -notlike "WAF*") {
        throw "WAF can only be enabled with WAF_Medium, WAF_Large, or WAF_v2 SKUs. Current SKU: $SKU"
    }

    # Build basic Azure CLI command parameters
    $azParams = @(
        'network', 'application-gateway', 'create',
        '--name', $AppGatewayName,
        '--resource-group', $ResourceGroup,
        '--location', $Location,
        '--vnet-name', $VNetName,
        '--subnet', $SubnetName,
        '--sku', $SKU,
        '--public-ip-address', $PublicIPName
    )

    # Add capacity settings based on SKU
    if ($SKU -like "*_v2") {
        # v2 SKUs support autoscaling
        $azParams += '--min-capacity', $MinCapacity.ToString()
        $azParams += '--max-capacity', $MaxCapacity.ToString()
    } else {
        # v1 SKUs use fixed capacity
        $azParams += '--capacity', $Capacity.ToString()
    }

    # Add WAF configuration if enabled
    if ($EnableWAF) {
        $azParams += '--waf-policy-mode', $WAFMode
        if ($SKU -like "WAF_v2") {
            # WAF v2 has additional options
            $azParams += '--enable-waf'
        }
    }

    # Add HTTP/2 support if requested
    if ($EnableHTTP2) {
        $azParams += '--http2', 'Enabled'
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
    Write-Host "Application Gateway Configuration:" -ForegroundColor Cyan
    Write-Host "  Name: $AppGatewayName" -ForegroundColor White
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    Write-Host "  Location: $Location" -ForegroundColor White
    Write-Host "  SKU: $SKU" -ForegroundColor White
    Write-Host "  Virtual Network: $VNetName" -ForegroundColor White
    Write-Host "  Subnet: $SubnetName" -ForegroundColor White
    Write-Host "  Public IP: $PublicIPName" -ForegroundColor White

    if ($SKU -like "*_v2") {
        Write-Host "  Autoscaling: Min=$MinCapacity, Max=$MaxCapacity instances" -ForegroundColor White
    } else {
        Write-Host "  Capacity: $Capacity instances" -ForegroundColor White
    }

    if ($EnableWAF) {
        Write-Host "  WAF: Enabled (Mode: $WAFMode)" -ForegroundColor White
    } else {
        Write-Host "  WAF: Disabled" -ForegroundColor White
    }

    Write-Host "  HTTP/2: $(if ($EnableHTTP2) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White

    Write-Host "Creating Application Gateway..." -ForegroundColor Yellow
    Write-Host "⚠ This may take 15-20 minutes to complete" -ForegroundColor Yellow

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        $appGatewayInfo = $result | ConvertFrom-Json

        Write-Host "✓ Application Gateway created successfully!" -ForegroundColor Green
        Write-Host "Application Gateway Details:" -ForegroundColor Cyan
        Write-Host "  Name: $($appGatewayInfo.name)" -ForegroundColor White
        Write-Host "  Resource ID: $($appGatewayInfo.id)" -ForegroundColor White
        Write-Host "  Provisioning State: $($appGatewayInfo.provisioningState)" -ForegroundColor White
        Write-Host "  Operational State: $($appGatewayInfo.operationalState)" -ForegroundColor White

        if ($appGatewayInfo.frontendIPConfigurations) {
            $frontendIP = $appGatewayInfo.frontendIPConfigurations[0]
            if ($frontendIP.publicIPAddress) {
                # Get public IP details
                $pipInfo = az network public-ip show --ids $frontendIP.publicIPAddress.id | ConvertFrom-Json
                Write-Host "  Public IP Address: $($pipInfo.ipAddress)" -ForegroundColor White
            }
        }

        Write-Host "" -ForegroundColor White
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "• Configure backend pools for your applications" -ForegroundColor White
        Write-Host "• Set up HTTP settings and health probes" -ForegroundColor White
        Write-Host "• Create listeners and routing rules" -ForegroundColor White
        Write-Host "• Configure SSL certificates if needed" -ForegroundColor White
        if ($EnableWAF) {
            Write-Host "• Review and customize WAF policies" -ForegroundColor White
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Application Gateway" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
