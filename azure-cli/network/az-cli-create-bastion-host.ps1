<#
.SYNOPSIS
    Create an Azure Bastion host using Azure CLI.

.DESCRIPTION
    This script creates an Azure Bastion host using the Azure CLI.
    Azure Bastion provides secure RDP/SSH connectivity to virtual machines without exposing them to the public internet.
    
    The script uses the Azure CLI command: az network bastion create

.PARAMETER Name
    The name of the Azure Bastion host to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the Bastion will be created.

.PARAMETER VNetName
    The name of the Virtual Network where the Bastion will be deployed.

.PARAMETER Location
    The Azure region where the Bastion will be created.

.PARAMETER PublicIPAddress
    The name or resource ID of an existing public IP address for the Bastion.

.PARAMETER Sku
    The SKU of the Azure Bastion host.
    Valid values: 'Basic', 'Standard'

.PARAMETER EnableTunneling
    Enable native client tunneling support (requires Standard SKU).

.PARAMETER EnableIpConnect
    Enable IP-based connection support (requires Standard SKU).

.PARAMETER EnableShareableLink
    Enable shareable link support (requires Standard SKU).

.PARAMETER ScaleUnits
    The number of scale units for the Bastion (2-50, requires Standard SKU).

.PARAMETER Tags
    Tags to apply to the Bastion in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-create-bastion-host.ps1 -Name "myBastion" -ResourceGroup "MyRG" -VNetName "myVNet" -Location "eastus" -PublicIPAddress "bastion-pip"
    
    Creates a basic Azure Bastion host.

.EXAMPLE
    .\az-cli-create-bastion-host.ps1 -Name "prodBastion" -ResourceGroup "prod-rg" -VNetName "prod-vnet" -Location "westus2" -PublicIPAddress "bastion-pip" -Sku "Standard" -EnableTunneling -EnableIpConnect -ScaleUnits 4
    
    Creates a Standard SKU Bastion with advanced features.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: Azure Bastion requires a dedicated subnet named 'AzureBastionSubnet' with minimum /27 prefix.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/bastion

.LINK
    https://learn.microsoft.com/en-us/azure/bastion/bastion-overview

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Bastion host")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-\.\_]{0,78}[a-zA-Z0-9\_]$|^[a-zA-Z0-9]$', ErrorMessage = "Bastion name must be 1-80 characters, start and end with alphanumeric or underscore, contain only letters, numbers, hyphens, periods, and underscores")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [string]$VNetName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the Bastion will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "The name or resource ID of the public IP address")]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIPAddress,

    [Parameter(HelpMessage = "The SKU of the Azure Bastion host")]
    [ValidateSet('Basic', 'Standard')]
    [string]$Sku = "Basic",

    [Parameter(HelpMessage = "Enable native client tunneling support")]
    [switch]$EnableTunneling,

    [Parameter(HelpMessage = "Enable IP-based connection support")]
    [switch]$EnableIpConnect,

    [Parameter(HelpMessage = "Enable shareable link support")]
    [switch]$EnableShareableLink,

    [Parameter(HelpMessage = "The number of scale units (2-50, Standard SKU only)")]
    [ValidateRange(2, 50)]
    [int]$ScaleUnits,

    [Parameter(HelpMessage = "Tags in the format 'key1=value1 key2=value2'")]
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

    # Verify the VNet exists
    Write-Host "Verifying Virtual Network exists..." -ForegroundColor Yellow
    $vnetCheck = az network vnet show --name $VNetName --resource-group $ResourceGroup 2>$null
    if (-not $vnetCheck) {
        throw "Virtual network '$VNetName' not found in resource group '$ResourceGroup'"
    }
    Write-Host "✓ Virtual Network '$VNetName' found" -ForegroundColor Green

    # Check for AzureBastionSubnet
    Write-Host "Checking for AzureBastionSubnet..." -ForegroundColor Yellow
    $vnetInfo = $vnetCheck | ConvertFrom-Json
    $bastionSubnet = $vnetInfo.subnets | Where-Object { $_.name -eq "AzureBastionSubnet" }
    if (-not $bastionSubnet) {
        Write-Host "⚠ Warning: AzureBastionSubnet not found. Bastion requires a dedicated subnet named 'AzureBastionSubnet' with minimum /27 prefix." -ForegroundColor Yellow
        Write-Host "Please create the subnet before deploying Bastion." -ForegroundColor Yellow
    } else {
        Write-Host "✓ AzureBastionSubnet found: $($bastionSubnet.addressPrefix)" -ForegroundColor Green
    }

    # Validate Standard SKU requirements
    if ($Sku -eq "Basic") {
        if ($EnableTunneling -or $EnableIpConnect -or $EnableShareableLink -or $ScaleUnits) {
            Write-Host "⚠ Warning: Advanced features require Standard SKU. Upgrading to Standard." -ForegroundColor Yellow
            $Sku = "Standard"
        }
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'bastion', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--vnet-name', $VNetName,
        '--location', $Location,
        '--public-ip-address', $PublicIPAddress,
        '--sku', $Sku
    )

    # Add Standard SKU features
    if ($Sku -eq "Standard") {
        if ($EnableTunneling) { 
            $azParams += '--enable-tunneling', 'true' 
        }
        if ($EnableIpConnect) { 
            $azParams += '--enable-ip-connect', 'true' 
        }
        if ($EnableShareableLink) { 
            $azParams += '--enable-shareable-link', 'true' 
        }
        if ($ScaleUnits) { 
            $azParams += '--scale-units', $ScaleUnits 
        }
    }

    # Add optional parameters
    if ($Tags) { 
        $azParams += '--tags', $Tags 
    }

    Write-Host "Creating Azure Bastion host..." -ForegroundColor Yellow
    Write-Host "Name: $Name" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
    Write-Host "VNet: $VNetName" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan
    Write-Host "SKU: $Sku" -ForegroundColor Cyan
    Write-Host "Public IP: $PublicIPAddress" -ForegroundColor Cyan

    if ($Sku -eq "Standard") {
        if ($EnableTunneling) {
            Write-Host "Native Client Support: Enabled" -ForegroundColor Green
        }
        if ($EnableIpConnect) {
            Write-Host "IP Connect: Enabled" -ForegroundColor Green
        }
        if ($EnableShareableLink) {
            Write-Host "Shareable Links: Enabled" -ForegroundColor Green
        }
        if ($ScaleUnits) {
            Write-Host "Scale Units: $ScaleUnits" -ForegroundColor Cyan
        }
    }

    Write-Host "" -ForegroundColor White
    Write-Host "⏱ Note: Bastion deployment typically takes 10-15 minutes..." -ForegroundColor Yellow

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Azure Bastion host created successfully!" -ForegroundColor Green
        
        # Parse and display Bastion information
        try {
            $bastionInfo = $result | ConvertFrom-Json
            Write-Host "Bastion Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($bastionInfo.name)" -ForegroundColor White
            Write-Host "  Resource Group: $($bastionInfo.resourceGroup)" -ForegroundColor White
            Write-Host "  Location: $($bastionInfo.location)" -ForegroundColor White
            Write-Host "  SKU: $($bastionInfo.sku.name)" -ForegroundColor White
            Write-Host "  Provisioning State: $($bastionInfo.provisioningState)" -ForegroundColor White
            
            if ($bastionInfo.ipConfigurations -and $bastionInfo.ipConfigurations.Count -gt 0) {
                $ipConfig = $bastionInfo.ipConfigurations[0]
                Write-Host "  Public IP: $($ipConfig.publicIPAddress.id -split '/')[-1]" -ForegroundColor White
                Write-Host "  Subnet: $($ipConfig.subnet.id -split '/')[-1]" -ForegroundColor White
            }
            
            if ($bastionInfo.scaleUnits) {
                Write-Host "  Scale Units: $($bastionInfo.scaleUnits)" -ForegroundColor White
            }
            
            Write-Host "" -ForegroundColor White
            Write-Host "✓ Bastion is ready for use!" -ForegroundColor Green
            Write-Host "You can now connect to VMs in the VNet via Azure Portal or native clients." -ForegroundColor White
        }
        catch {
            Write-Host "Bastion created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Azure Bastion host" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
