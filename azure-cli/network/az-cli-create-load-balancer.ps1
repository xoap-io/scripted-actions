<#
.SYNOPSIS
    Create an Azure Load Balancer using Azure CLI.

.DESCRIPTION
    This script creates an Azure Load Balancer using the Azure CLI.
    Load balancers distribute incoming network traffic across multiple backend resources for high availability and scalability.

    The script uses the Azure CLI command: az network lb create

.PARAMETER Name
    The name of the Load Balancer to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the Load Balancer will be created.

.PARAMETER Location
    The Azure region where the Load Balancer will be created.

.PARAMETER Sku
    The SKU of the Load Balancer.
    Valid values: 'Basic', 'Standard', 'Gateway'

.PARAMETER Type
    The type of Load Balancer.
    Valid values: 'Public', 'Internal'

.PARAMETER FrontendIPName
    The name of the frontend IP configuration.

.PARAMETER PublicIPAddress
    The name or resource ID of an existing public IP address (for Public load balancers).

.PARAMETER SubnetId
    The resource ID of the subnet (for Internal load balancers).

.PARAMETER PrivateIPAddress
    The private IP address for the frontend (for Internal load balancers with static IP).

.PARAMETER BackendPoolName
    The name of the backend address pool.

.PARAMETER Tags
    Tags to apply to the Load Balancer in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-create-load-balancer.ps1 -Name "web-lb" -ResourceGroup "MyRG" -Location "eastus" -Type "Public" -PublicIPAddress "web-pip"

    Creates a public load balancer with an existing public IP.

.EXAMPLE
    .\az-cli-create-load-balancer.ps1 -Name "app-lb" -ResourceGroup "MyRG" -Location "westus2" -Type "Internal" -SubnetId "/subscriptions/.../subnets/app-subnet" -Sku "Standard"

    Creates an internal Standard load balancer.

.EXAMPLE
    .\az-cli-create-load-balancer.ps1 -Name "internal-lb" -ResourceGroup "MyRG" -Location "eastus2" -Type "Internal" -SubnetId "/subscriptions/.../subnets/app-subnet" -PrivateIPAddress "10.0.1.10" -Tags "environment=production tier=application"

    Creates an internal load balancer with a static private IP and tags.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/lb

.LINK
    https://learn.microsoft.com/en-us/azure/load-balancer/load-balancer-overview

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Load Balancer")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-\.\_]{0,78}[a-zA-Z0-9\_]$|^[a-zA-Z0-9]$', ErrorMessage = "Load balancer name must be 1-80 characters, start and end with alphanumeric or underscore, contain only letters, numbers, hyphens, periods, and underscores")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the Load Balancer will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(HelpMessage = "The SKU of the Load Balancer")]
    [ValidateSet('Basic', 'Standard', 'Gateway')]
    [string]$Sku = "Standard",

    [Parameter(Mandatory = $true, HelpMessage = "The type of Load Balancer")]
    [ValidateSet('Public', 'Internal')]
    [string]$Type,

    [Parameter(HelpMessage = "The name of the frontend IP configuration")]
    [string]$FrontendIPName = "LoadBalancerFrontEnd",

    [Parameter(HelpMessage = "The name or resource ID of the public IP address")]
    [string]$PublicIPAddress,

    [Parameter(HelpMessage = "The resource ID of the subnet for internal load balancer")]
    [ValidatePattern('^/subscriptions/[0-9a-f-]+/resourceGroups/.+/providers/Microsoft\.Network/virtualNetworks/.+/subnets/.+$', ErrorMessage = "Subnet ID must be a valid Azure subnet resource ID")]
    [string]$SubnetId,

    [Parameter(HelpMessage = "The private IP address for internal load balancer")]
    [ValidatePattern('^(\d{1,3}\.){3}\d{1,3}$', ErrorMessage = "Private IP must be a valid IPv4 address")]
    [string]$PrivateIPAddress,

    [Parameter(HelpMessage = "The name of the backend address pool")]
    [string]$BackendPoolName = "LoadBalancerBackEnd",

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

    # Validate type-specific requirements
    if ($Type -eq "Public" -and -not $PublicIPAddress) {
        throw "PublicIPAddress is required when Type is 'Public'"
    }
    if ($Type -eq "Internal" -and -not $SubnetId) {
        throw "SubnetId is required when Type is 'Internal'"
    }
    if ($Type -eq "Public" -and ($SubnetId -or $PrivateIPAddress)) {
        Write-Host "⚠ Warning: SubnetId and PrivateIPAddress are ignored for Public load balancers" -ForegroundColor Yellow
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'lb', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--location', $Location,
        '--sku', $Sku,
        '--frontend-ip-name', $FrontendIPName,
        '--backend-pool-name', $BackendPoolName
    )

    # Add type-specific parameters
    if ($Type -eq "Public") {
        $azParams += '--public-ip-address', $PublicIPAddress
    } else {
        $azParams += '--subnet', $SubnetId
        if ($PrivateIPAddress) {
            $azParams += '--private-ip-address', $PrivateIPAddress
        }
    }

    # Add optional parameters
    if ($Tags) {
        $azParams += '--tags', $Tags
    }

    Write-Host "Creating Load Balancer..." -ForegroundColor Yellow
    Write-Host "Name: $Name" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan
    Write-Host "SKU: $Sku" -ForegroundColor Cyan
    Write-Host "Type: $Type" -ForegroundColor Cyan

    if ($Type -eq "Public") {
        Write-Host "Public IP: $PublicIPAddress" -ForegroundColor Cyan
    } else {
        Write-Host "Subnet: $($SubnetId -split '/')[-1]" -ForegroundColor Cyan
        if ($PrivateIPAddress) {
            Write-Host "Private IP: $PrivateIPAddress" -ForegroundColor Cyan
        } else {
            Write-Host "Private IP: Dynamic" -ForegroundColor Cyan
        }
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Load Balancer created successfully!" -ForegroundColor Green

        # Parse and display Load Balancer information
        try {
            $lbInfo = $result | ConvertFrom-Json
            Write-Host "Load Balancer Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($lbInfo.name)" -ForegroundColor White
            Write-Host "  Resource Group: $($lbInfo.resourceGroup)" -ForegroundColor White
            Write-Host "  Location: $($lbInfo.location)" -ForegroundColor White
            Write-Host "  SKU: $($lbInfo.sku.name)" -ForegroundColor White
            Write-Host "  Resource ID: $($lbInfo.id)" -ForegroundColor White

            if ($lbInfo.frontendIPConfigurations -and $lbInfo.frontendIPConfigurations.Count -gt 0) {
                $frontend = $lbInfo.frontendIPConfigurations[0]
                Write-Host "  Frontend IP Configuration:" -ForegroundColor White
                Write-Host "    Name: $($frontend.name)" -ForegroundColor White

                if ($frontend.publicIPAddress) {
                    Write-Host "    Type: Public" -ForegroundColor White
                    Write-Host "    Public IP: $($frontend.publicIPAddress.id -split '/')[-1]" -ForegroundColor White
                } else {
                    Write-Host "    Type: Internal" -ForegroundColor White
                    Write-Host "    Private IP: $($frontend.privateIPAddress)" -ForegroundColor White
                    Write-Host "    Subnet: $($frontend.subnet.id -split '/')[-1]" -ForegroundColor White
                }
            }

            if ($lbInfo.backendAddressPools -and $lbInfo.backendAddressPools.Count -gt 0) {
                Write-Host "  Backend Pool: $($lbInfo.backendAddressPools[0].name)" -ForegroundColor White
            }

            if ($lbInfo.tags -and $lbInfo.tags.PSObject.Properties.Count -gt 0) {
                Write-Host "  Tags:" -ForegroundColor White
                $lbInfo.tags.PSObject.Properties | ForEach-Object {
                    Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor White
                }
            }

            Write-Host "" -ForegroundColor White
            Write-Host "Next steps:" -ForegroundColor Yellow
            Write-Host "  1. Add backend pool members (VMs or VM Scale Sets)" -ForegroundColor White
            Write-Host "  2. Create load balancing rules" -ForegroundColor White
            Write-Host "  3. Configure health probes" -ForegroundColor White
        }
        catch {
            Write-Host "Load Balancer created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Load Balancer" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
