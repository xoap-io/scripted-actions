<#
.SYNOPSIS
    Create an Azure Route Table using Azure CLI.

.DESCRIPTION
    This script creates an Azure Route Table using the Azure CLI.
    Route tables contain custom routes that override Azure's default system routes for subnet traffic.
    
    The script uses the Azure CLI command: az network route-table create

.PARAMETER Name
    The name of the Route Table to create.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the Route Table will be created.

.PARAMETER Location
    The Azure region where the Route Table will be created.

.PARAMETER DisableBgpRoutePropagation
    Disable BGP route propagation for this route table.

.PARAMETER Tags
    Tags to apply to the Route Table in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-create-route-table.ps1 -Name "app-routes" -ResourceGroup "MyRG" -Location "eastus"
    
    Creates a basic route table.

.EXAMPLE
    .\az-cli-create-route-table.ps1 -Name "secure-routes" -ResourceGroup "MyRG" -Location "westus2" -DisableBgpRoutePropagation -Tags "environment=production purpose=security"
    
    Creates a route table with BGP route propagation disabled and tags.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/route-table

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-udr-overview

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Route Table")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-\.\_]{0,78}[a-zA-Z0-9\_]$|^[a-zA-Z0-9]$', ErrorMessage = "Route table name must be 1-80 characters, start and end with alphanumeric or underscore, contain only letters, numbers, hyphens, periods, and underscores")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the Route Table will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(HelpMessage = "Disable BGP route propagation")]
    [switch]$DisableBgpRoutePropagation,

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

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'route-table', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--location', $Location
    )

    # Add optional parameters
    if ($DisableBgpRoutePropagation) { 
        $azParams += '--disable-bgp-route-propagation', 'true' 
    }
    if ($Tags) { 
        $azParams += '--tags', $Tags 
    }

    Write-Host "Creating Route Table..." -ForegroundColor Yellow
    Write-Host "Name: $Name" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
    Write-Host "Location: $Location" -ForegroundColor Cyan

    if ($DisableBgpRoutePropagation) {
        Write-Host "BGP Route Propagation: Disabled" -ForegroundColor Yellow
    } else {
        Write-Host "BGP Route Propagation: Enabled" -ForegroundColor Green
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Route Table created successfully!" -ForegroundColor Green
        
        # Parse and display Route Table information
        try {
            $rtInfo = $result | ConvertFrom-Json
            Write-Host "Route Table Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($rtInfo.name)" -ForegroundColor White
            Write-Host "  Resource Group: $($rtInfo.resourceGroup)" -ForegroundColor White
            Write-Host "  Location: $($rtInfo.location)" -ForegroundColor White
            Write-Host "  Resource ID: $($rtInfo.id)" -ForegroundColor White
            Write-Host "  BGP Route Propagation: $(if ($rtInfo.disableBgpRoutePropagation) { 'Disabled' } else { 'Enabled' })" -ForegroundColor White
            
            if ($rtInfo.routes -and $rtInfo.routes.Count -gt 0) {
                Write-Host "  Custom Routes: $($rtInfo.routes.Count)" -ForegroundColor White
            } else {
                Write-Host "  Custom Routes: None (only system routes active)" -ForegroundColor White
            }
            
            if ($rtInfo.tags -and $rtInfo.tags.PSObject.Properties.Count -gt 0) {
                Write-Host "  Tags:" -ForegroundColor White
                $rtInfo.tags.PSObject.Properties | ForEach-Object {
                    Write-Host "    $($_.Name): $($_.Value)" -ForegroundColor White
                }
            }
        }
        catch {
            Write-Host "Route Table created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Route Table" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
