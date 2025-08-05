<#
.SYNOPSIS
    Create an Azure Public IP address using Azure CLI.

.DESCRIPTION
    This script creates an Azure Public IP address using the Azure CLI.
    Public IP addresses enable Azure resources to communicate to the internet and public-facing Azure services.
    
    The script uses the Azure CLI command: az network public-ip create

.PARAMETER Name
    The name of the Public IP address to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the Public IP will be created.

.PARAMETER Location
    The Azure region where the Public IP will be created.

.PARAMETER AllocationMethod
    The IP address allocation method.
    Valid values: 'Dynamic', 'Static'

.PARAMETER Sku
    The SKU of the Public IP address.
    Valid values: 'Basic', 'Standard'

.PARAMETER Version
    The IP version.
    Valid values: 'IPv4', 'IPv6'

.PARAMETER DnsName
    The DNS name label for the Public IP address (creates FQDN: <dns-name>.<location>.cloudapp.azure.com).

.PARAMETER IdleTimeout
    The idle timeout value in minutes (4-30).

.PARAMETER Zone
    The availability zone for the Public IP address.
    Valid values: '1', '2', '3'

.PARAMETER Tags
    Tags to apply to the Public IP in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-create-public-ip.ps1 -Name "myPublicIP" -ResourceGroup "MyRG" -Location "eastus"
    
    Creates a basic dynamic Public IP address.

.EXAMPLE
    .\az-cli-create-public-ip.ps1 -Name "myStaticIP" -ResourceGroup "MyRG" -Location "westus2" -AllocationMethod "Static" -Sku "Standard" -DnsName "myapp"
    
    Creates a static Standard SKU Public IP with DNS name.

.EXAMPLE
    .\az-cli-create-public-ip.ps1 -Name "myZonalIP" -ResourceGroup "MyRG" -Location "eastus2" -AllocationMethod "Static" -Sku "Standard" -Zone "1" -Tags "environment=production"
    
    Creates a zone-redundant static Public IP with tags.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/public-ip

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/public-ip-addresses

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Public IP address")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-\.\_]{0,78}[a-zA-Z0-9\_]$|^[a-zA-Z0-9]$', ErrorMessage = "Public IP name must be 1-80 characters, start and end with alphanumeric or underscore, contain only letters, numbers, hyphens, periods, and underscores")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the Public IP will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(HelpMessage = "The IP address allocation method")]
    [ValidateSet('Dynamic', 'Static')]
    [string]$AllocationMethod = "Dynamic",

    [Parameter(HelpMessage = "The SKU of the Public IP address")]
    [ValidateSet('Basic', 'Standard')]
    [string]$Sku = "Basic",

    [Parameter(HelpMessage = "The IP version")]
    [ValidateSet('IPv4', 'IPv6')]
    [string]$Version = "IPv4",

    [Parameter(HelpMessage = "The DNS name label for the Public IP address")]
    [ValidatePattern('^[a-z0-9][a-z0-9\-]{0,61}[a-z0-9]$|^[a-z0-9]$', ErrorMessage = "DNS name must be 1-63 characters, lowercase letters, numbers, and hyphens only")]
    [string]$DnsName,

    [Parameter(HelpMessage = "The idle timeout value in minutes (4-30)")]
    [ValidateRange(4, 30)]
    [int]$IdleTimeout = 4,

    [Parameter(HelpMessage = "The availability zone for the Public IP address")]
    [ValidateSet('1', '2', '3')]
    [string]$Zone,

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

    # Validate SKU and allocation method compatibility
    if ($Sku -eq "Standard" -and $AllocationMethod -eq "Dynamic") {
        Write-Host "⚠ Warning: Standard SKU requires Static allocation method. Changing to Static." -ForegroundColor Yellow
        $AllocationMethod = "Static"
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'public-ip', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--location', $Location,
        '--allocation-method', $AllocationMethod,
        '--sku', $Sku,
        '--version', $Version,
        '--idle-timeout', $IdleTimeout
    )

    # Add optional parameters
    if ($DnsName) { 
        $azParams += '--dns-name', $DnsName 
    }
    if ($Zone) { 
        $azParams += '--zone', $Zone 
    }
    if ($Tags) { 
        $azParams += '--tags', $Tags 
    }

    Write-Host "Creating Public IP address..." -ForegroundColor Yellow
    Write-Host "Name: $Name" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan
    Write-Host "Allocation Method: $AllocationMethod" -ForegroundColor Cyan
    Write-Host "SKU: $Sku" -ForegroundColor Cyan
    Write-Host "IP Version: $Version" -ForegroundColor Cyan

    if ($DnsName) {
        Write-Host "DNS Name: $DnsName.$Location.cloudapp.azure.com" -ForegroundColor Cyan
    }
    if ($Zone) {
        Write-Host "Availability Zone: $Zone" -ForegroundColor Cyan
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Public IP address created successfully!" -ForegroundColor Green
        
        # Parse and display Public IP information
        try {
            $pipInfo = $result | ConvertFrom-Json
            Write-Host "Public IP Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($pipInfo.name)" -ForegroundColor White
            Write-Host "  Resource Group: $($pipInfo.resourceGroup)" -ForegroundColor White
            Write-Host "  Location: $($pipInfo.location)" -ForegroundColor White
            Write-Host "  SKU: $($pipInfo.sku.name)" -ForegroundColor White
            Write-Host "  Allocation Method: $($pipInfo.publicIPAllocationMethod)" -ForegroundColor White
            Write-Host "  IP Version: $($pipInfo.publicIPAddressVersion)" -ForegroundColor White
            Write-Host "  Resource ID: $($pipInfo.id)" -ForegroundColor White
            
            if ($pipInfo.ipAddress) {
                Write-Host "  IP Address: $($pipInfo.ipAddress)" -ForegroundColor Green
            }
            if ($pipInfo.dnsSettings -and $pipInfo.dnsSettings.fqdn) {
                Write-Host "  FQDN: $($pipInfo.dnsSettings.fqdn)" -ForegroundColor Green
            }
            if ($pipInfo.zones -and $pipInfo.zones.Count -gt 0) {
                Write-Host "  Availability Zone: $($pipInfo.zones -join ', ')" -ForegroundColor White
            }
            if ($pipInfo.tags -and $pipInfo.tags.PSObject.Properties.Count -gt 0) {
                Write-Host "  Tags:" -ForegroundColor White
                $pipInfo.tags.PSObject.Properties | ForEach-Object {
                    Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor White
                }
            }
        }
        catch {
            Write-Host "Public IP created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Public IP address" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
