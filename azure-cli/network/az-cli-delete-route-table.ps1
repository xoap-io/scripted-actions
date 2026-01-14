<#
.SYNOPSIS
    Delete an Azure Route Table using Azure CLI.

.DESCRIPTION
    This script deletes an Azure Route Table using the Azure CLI.
    Includes safety checks to verify the route table is not associated with any subnets
    and provides confirmation prompts to prevent accidental deletion.

    The script uses the Azure CLI command: az network route-table delete

.PARAMETER RouteTableName
    The name of the Route Table to delete.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the Route Table.

.PARAMETER Force
    Force deletion without confirmation prompts.

.PARAMETER SkipAssociationCheck
    Skip checking for subnet associations.

.EXAMPLE
    .\az-cli-delete-route-table.ps1 -RouteTableName "prod-rt" -ResourceGroup "network-rg"

    Deletes a Route Table with safety checks and confirmation.

.EXAMPLE
    .\az-cli-delete-route-table.ps1 -RouteTableName "prod-rt" -ResourceGroup "network-rg" -Force

    Forces deletion without confirmation prompts but still checks associations.

.EXAMPLE
    .\az-cli-delete-route-table.ps1 -RouteTableName "prod-rt" -ResourceGroup "network-rg" -Force -SkipAssociationCheck

    Forces deletion without any safety checks or confirmations.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Warning: Deleting a route table while it's associated with subnets may affect network routing.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/route-table

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Route Table to delete")]
    [ValidateNotNullOrEmpty()]
    [string]$RouteTableName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Force deletion without confirmation")]
    [switch]$Force,

    [Parameter(HelpMessage = "Skip checking for subnet associations")]
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

    # Verify the Route Table exists
    Write-Host "Verifying Route Table exists..." -ForegroundColor Yellow
    $routeTableCheck = az network route-table show --name $RouteTableName --resource-group $ResourceGroup 2>$null
    if (-not $routeTableCheck) {
        throw "Route Table '$RouteTableName' not found in resource group '$ResourceGroup'"
    }

    $routeTableInfo = $routeTableCheck | ConvertFrom-Json
    Write-Host "✓ Route Table '$RouteTableName' found" -ForegroundColor Green

    # Display Route Table details
    Write-Host "Route Table Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($routeTableInfo.name)" -ForegroundColor White
    Write-Host "  Location: $($routeTableInfo.location)" -ForegroundColor White
    Write-Host "  Resource Group: $($routeTableInfo.resourceGroup)" -ForegroundColor White
    Write-Host "  BGP Route Propagation: $($routeTableInfo.disableBgpRoutePropagation)" -ForegroundColor White
    Write-Host "  Routes: $($routeTableInfo.routes.Count) custom routes" -ForegroundColor White

    # Display custom routes if any
    if ($routeTableInfo.routes -and $routeTableInfo.routes.Count -gt 0) {
        Write-Host "  Custom Routes:" -ForegroundColor Blue
        foreach ($route in $routeTableInfo.routes) {
            Write-Host "    • $($route.name): $($route.addressPrefix) → $($route.nextHopType)" -ForegroundColor White
        }
    }

    # Check for subnet associations unless skipped
    if (-not $SkipAssociationCheck) {
        Write-Host "Checking for subnet associations..." -ForegroundColor Yellow

        if ($routeTableInfo.subnets -and $routeTableInfo.subnets.Count -gt 0) {
            Write-Host "⚠ WARNING: Route Table has active subnet associations!" -ForegroundColor Red
            Write-Host "Associated Subnets:" -ForegroundColor Yellow

            foreach ($subnet in $routeTableInfo.subnets) {
                $subnetName = ($subnet.id -split '/')[-1]
                $vnetName = ($subnet.id -split '/')[-3]
                $subnetRG = ($subnet.id -split '/')[-7]
                Write-Host "  • Subnet: $subnetName (VNet: $vnetName, RG: $subnetRG)" -ForegroundColor White
            }

            Write-Host "" -ForegroundColor White
            Write-Host "Deleting this route table will remove custom routing from these subnets!" -ForegroundColor Red
            Write-Host "Subnets will fall back to system routes only." -ForegroundColor Yellow

            if (-not $Force) {
                Write-Host "" -ForegroundColor White
                $confirmation = Read-Host "Do you want to continue with deletion despite subnet associations? (yes/no)"
                if ($confirmation -ne "yes") {
                    Write-Host "Deletion cancelled due to subnet associations." -ForegroundColor Yellow
                    Write-Host "To proceed, first disassociate the route table from all subnets or use -Force parameter." -ForegroundColor Blue
                    exit 0
                }
            }
        } else {
            Write-Host "✓ No subnet associations found" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠ Skipping association checks as requested" -ForegroundColor Yellow
    }

    # Final confirmation prompt unless forced
    if (-not $Force) {
        Write-Host "" -ForegroundColor White
        Write-Host "⚠ WARNING: This will permanently delete the Route Table '$RouteTableName'" -ForegroundColor Red
        Write-Host "All custom routes will be lost and cannot be recovered!" -ForegroundColor Red
        Write-Host "" -ForegroundColor White

        $confirmation = Read-Host "Are you sure you want to delete this Route Table? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "Deletion cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'route-table', 'delete',
        '--name', $RouteTableName,
        '--resource-group', $ResourceGroup,
        '--yes'  # Skip confirmation in Azure CLI
    )

    Write-Host "Deleting Route Table..." -ForegroundColor Yellow
    Write-Host "Name: $RouteTableName" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Route Table deleted successfully!" -ForegroundColor Green
        Write-Host "Route Table '$RouteTableName' has been permanently removed from resource group '$ResourceGroup'" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "Important reminders:" -ForegroundColor Yellow
        Write-Host "• Previously associated subnets now use system routes only" -ForegroundColor White
        Write-Host "• Custom routing configurations have been lost" -ForegroundColor White
        Write-Host "• Verify network connectivity if this was a critical route table" -ForegroundColor White
        Write-Host "• Consider creating new route tables if custom routing is still needed" -ForegroundColor White
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to delete Route Table" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
