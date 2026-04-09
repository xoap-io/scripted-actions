<#
.SYNOPSIS
    Create an Azure NAT Gateway and optionally associate it with a subnet using the Azure CLI.

.DESCRIPTION
    This script creates an Azure NAT Gateway using the Azure CLI. Optionally, it creates
    a public IP address and associates the NAT Gateway with a specified VNet subnet.
    The script uses the following Azure CLI commands:
    az network nat gateway create --resource-group $ResourceGroupName --name $NatGatewayName
    az network vnet subnet update --nat-gateway $NatGatewayId (when VnetName is provided)

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group where the NAT Gateway will be created.

.PARAMETER NatGatewayName
    Defines the name of the NAT Gateway resource.

.PARAMETER Location
    Defines the Azure region where the NAT Gateway will be created.

.PARAMETER IdleTimeoutMinutes
    Defines the idle timeout for NAT Gateway flows in minutes (4-120). Default: 4.

.PARAMETER Sku
    Defines the NAT Gateway SKU. Default: Standard.

.PARAMETER VnetName
    Defines the name of the virtual network to associate the NAT Gateway with.
    If provided, SubnetName must also be specified.

.PARAMETER SubnetName
    Defines the name of the subnet to associate the NAT Gateway with.
    Required when VnetName is specified.

.PARAMETER PublicIpName
    Defines the name of a new public IP address to create and attach to the NAT Gateway.
    If not specified, no new public IP is created automatically.

.EXAMPLE
    .\az-cli-create-nat-gateway.ps1 -ResourceGroupName "rg-network" -NatGatewayName "nat-gw-prod" -Location "eastus" -PublicIpName "nat-gw-pip"

.EXAMPLE
    .\az-cli-create-nat-gateway.ps1 -ResourceGroupName "rg-network" -NatGatewayName "nat-gw-prod" -Location "eastus" -IdleTimeoutMinutes 10 -VnetName "prod-vnet" -SubnetName "private-subnet" -PublicIpName "nat-gw-pip"

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
    https://learn.microsoft.com/en-us/cli/azure/network/nat/gateway

.COMPONENT
    Azure CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group where the NAT Gateway will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the NAT Gateway resource")]
    [ValidateNotNullOrEmpty()]
    [string]$NatGatewayName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the NAT Gateway will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Idle timeout for NAT Gateway flows in minutes (4-120)")]
    [ValidateRange(4, 120)]
    [int]$IdleTimeoutMinutes = 4,

    [Parameter(Mandatory = $false, HelpMessage = "The NAT Gateway SKU")]
    [ValidateNotNullOrEmpty()]
    [string]$Sku = 'Standard',

    [Parameter(Mandatory = $false, HelpMessage = "The name of the virtual network to associate the NAT Gateway with")]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the subnet to associate the NAT Gateway with (required when VnetName is specified)")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of a new public IP address to create and attach to the NAT Gateway")]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpName
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating NAT Gateway '$NatGatewayName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Validate VNet/subnet dependency
    if ($VnetName -and -not $SubnetName) {
        throw "SubnetName must be specified when VnetName is provided."
    }
    if ($SubnetName -and -not $VnetName) {
        throw "VnetName must be specified when SubnetName is provided."
    }

    # Create public IP if requested
    if ($PublicIpName) {
        Write-Host "🔧 Creating public IP address '$PublicIpName'..." -ForegroundColor Cyan
        az network public-ip create `
            --resource-group $ResourceGroupName `
            --name $PublicIpName `
            --location $Location `
            --sku Standard `
            --allocation-method Static `
            --output none

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create public IP address '$PublicIpName'."
        }
        Write-Host "✅ Public IP address '$PublicIpName' created." -ForegroundColor Green
    }

    # Build the NAT Gateway create arguments
    $natArgs = @(
        'network', 'nat', 'gateway', 'create',
        '--resource-group', $ResourceGroupName,
        '--name', $NatGatewayName,
        '--location', $Location,
        '--idle-timeout', $IdleTimeoutMinutes,
        '--sku', $Sku,
        '--output', 'json'
    )

    if ($PublicIpName) {
        $natArgs += '--public-ip-addresses'
        $natArgs += $PublicIpName
    }

    # Create the NAT Gateway
    Write-Host "🔧 Creating NAT Gateway '$NatGatewayName'..." -ForegroundColor Cyan
    $natJson = az @natArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI nat gateway create command failed with exit code $LASTEXITCODE"
    }

    $natGateway = $natJson | ConvertFrom-Json

    Write-Host "✅ NAT Gateway '$NatGatewayName' created. ID: $($natGateway.id)" -ForegroundColor Green

    # Associate with subnet if specified
    if ($VnetName) {
        Write-Host "🔧 Associating NAT Gateway with subnet '$SubnetName' in VNet '$VnetName'..." -ForegroundColor Cyan
        az network vnet subnet update `
            --resource-group $ResourceGroupName `
            --vnet-name $VnetName `
            --name $SubnetName `
            --nat-gateway $natGateway.id `
            --output none

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to associate NAT Gateway with subnet '$SubnetName'."
        }
        Write-Host "✅ NAT Gateway associated with subnet '$SubnetName'." -ForegroundColor Green
    }

    Write-Host "`n✅ NAT Gateway '$NatGatewayName' configured successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   NatGatewayName:     $($natGateway.name)" -ForegroundColor White
    Write-Host "   Resource Group:     $($natGateway.resourceGroup)" -ForegroundColor White
    Write-Host "   Location:           $($natGateway.location)" -ForegroundColor White
    Write-Host "   Sku:                $($natGateway.sku.name)" -ForegroundColor White
    Write-Host "   IdleTimeoutMinutes: $IdleTimeoutMinutes" -ForegroundColor White

    if ($VnetName) {
        Write-Host "   VNet:               $VnetName" -ForegroundColor White
        Write-Host "   Subnet:             $SubnetName" -ForegroundColor White
    }

    Write-Host "   ProvisioningState:  $($natGateway.provisioningState)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
