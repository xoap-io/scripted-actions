<#
.SYNOPSIS
    Delete an Azure subnet using Azure CLI.

.DESCRIPTION
    This script deletes a subnet from an existing Azure Virtual Network using the Azure CLI.
    Includes safety checks to prevent accidental deletion of subnets with associated resources.
    
    The script uses the Azure CLI command: az network vnet subnet delete

.PARAMETER VNetName
    The name of the existing Azure Virtual Network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the virtual network.

.PARAMETER SubnetName
    The name of the subnet to delete.

.PARAMETER Force
    Force deletion without confirmation prompts.

.PARAMETER CheckAssociations
    Check for associated resources before deletion (default: true).

.EXAMPLE
    .\az-cli-delete-subnet.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "old-subnet"
    
    Deletes a subnet with confirmation and association checks.

.EXAMPLE
    .\az-cli-delete-subnet.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "old-subnet" -Force
    
    Forces deletion without confirmation prompts.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet/subnet

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the existing Azure Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [string]$VNetName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the subnet to delete")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(HelpMessage = "Force deletion without confirmation")]
    [switch]$Force,

    [Parameter(HelpMessage = "Skip checking for associated resources before deletion")]
    [switch]$SkipAssociationCheck
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

    # Verify the VNet and subnet exist
    Write-Host "Verifying subnet exists..." -ForegroundColor Yellow
    $subnetCheck = az network vnet subnet show --vnet-name $VNetName --resource-group $ResourceGroup --name $SubnetName 2>$null
    if (-not $subnetCheck) {
        throw "Subnet '$SubnetName' not found in virtual network '$VNetName' in resource group '$ResourceGroup'"
    }
    
    $subnetInfo = $subnetCheck | ConvertFrom-Json
    Write-Host "✓ Subnet '$SubnetName' found" -ForegroundColor Green
    Write-Host "  Address Prefix: $($subnetInfo.addressPrefix)" -ForegroundColor Cyan

    # Check for associated resources if not skipped
    if (-not $SkipAssociationCheck) {
        Write-Host "Checking for associated resources..." -ForegroundColor Yellow
        
        $hasAssociations = $false
        $associations = @()

        # Check for network interfaces
        if ($subnetInfo.ipConfigurations -and $subnetInfo.ipConfigurations.Count -gt 0) {
            $hasAssociations = $true
            $associations += "Network Interfaces ($($subnetInfo.ipConfigurations.Count))"
        }

        # Check for network security group
        if ($subnetInfo.networkSecurityGroup) {
            $associations += "Network Security Group: $($subnetInfo.networkSecurityGroup.id -split '/')[-1]"
        }

        # Check for route table
        if ($subnetInfo.routeTable) {
            $associations += "Route Table: $($subnetInfo.routeTable.id -split '/')[-1]"
        }

        # Check for service endpoints
        if ($subnetInfo.serviceEndpoints -and $subnetInfo.serviceEndpoints.Count -gt 0) {
            $associations += "Service Endpoints: $($subnetInfo.serviceEndpoints.service -join ', ')"
        }

        # Check for delegations
        if ($subnetInfo.delegations -and $subnetInfo.delegations.Count -gt 0) {
            $associations += "Delegations: $($subnetInfo.delegations.serviceName -join ', ')"
        }

        if ($hasAssociations) {
            Write-Host "⚠ Warning: Subnet has active network interfaces that will prevent deletion:" -ForegroundColor Red
            $associations | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
            
            if (-not $Force) {
                Write-Host "Deletion aborted. Remove associated resources first or use -Force to attempt deletion." -ForegroundColor Red
                exit 1
            } else {
                Write-Host "Force flag specified. Attempting deletion..." -ForegroundColor Yellow
            }
        } elseif ($associations.Count -gt 0) {
            Write-Host "ℹ Subnet associations found (will be removed):" -ForegroundColor Blue
            $associations | ForEach-Object { Write-Host "  - $_" -ForegroundColor Cyan }
        } else {
            Write-Host "✓ No blocking associations found" -ForegroundColor Green
        }
    }

    # Confirmation prompt unless forced
    if (-not $Force) {
        Write-Host "" -ForegroundColor White
        Write-Host "⚠ WARNING: This will permanently delete the subnet '$SubnetName'" -ForegroundColor Red
        Write-Host "VNet: $VNetName" -ForegroundColor Yellow
        Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Yellow
        Write-Host "Address Prefix: $($subnetInfo.addressPrefix)" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor White
        
        $confirmation = Read-Host "Are you sure you want to delete this subnet? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "Deletion cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'vnet', 'subnet', 'delete',
        '--vnet-name', $VNetName,
        '--resource-group', $ResourceGroup,
        '--name', $SubnetName
    )

    Write-Host "Deleting subnet..." -ForegroundColor Yellow
    Write-Host "VNet: $VNetName" -ForegroundColor Cyan
    Write-Host "Subnet: $SubnetName" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Subnet deleted successfully!" -ForegroundColor Green
        Write-Host "Subnet '$SubnetName' has been removed from virtual network '$VNetName'" -ForegroundColor White
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to delete subnet" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
