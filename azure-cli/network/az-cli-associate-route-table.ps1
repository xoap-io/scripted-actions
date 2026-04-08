<#
.SYNOPSIS
    Associate a Route Table with an Azure subnet using Azure CLI.

.DESCRIPTION
    This script associates an existing Route Table with a subnet in an Azure Virtual Network using the Azure CLI.
    Can also be used to remove route table association.

    The script uses the Azure CLI command: az network vnet subnet update

.PARAMETER VNetName
    The name of the existing Azure Virtual Network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the virtual network.

.PARAMETER SubnetName
    The name of the subnet to update.

.PARAMETER RouteTableName
    The name of the Route Table to associate (leave empty to remove association).

.PARAMETER RouteTableResourceGroup
    The resource group containing the Route Table (if different from subnet's resource group).

.PARAMETER RemoveRouteTable
    Remove the current Route Table association from the subnet.

.EXAMPLE
    .\az-cli-associate-route-table.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "app-subnet" -RouteTableName "app-routes"

    Associates a Route Table with a subnet.

.EXAMPLE
    .\az-cli-associate-route-table.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "app-subnet" -RouteTableName "app-routes" -RouteTableResourceGroup "network-rg"

    Associates a Route Table from a different resource group.

.EXAMPLE
    .\az-cli-associate-route-table.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "app-subnet" -RemoveRouteTable

    Removes the Route Table association from a subnet.

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

.COMPONENT
    Azure CLI Network
#>

[CmdletBinding(DefaultParameterSetName = 'Associate')]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the existing Azure Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [string]$VNetName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the subnet to update")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(ParameterSetName = 'Associate', HelpMessage = "The name of the Route Table")]
    [ValidateNotNullOrEmpty()]
    [string]$RouteTableName,

    [Parameter(ParameterSetName = 'Associate', HelpMessage = "The resource group containing the Route Table")]
    [string]$RouteTableResourceGroup,

    [Parameter(ParameterSetName = 'Remove', HelpMessage = "Remove the Route Table association")]
    [switch]$RemoveRouteTable
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

    # Verify the subnet exists
    Write-Host "Verifying subnet exists..." -ForegroundColor Yellow
    $subnetCheck = az network vnet subnet show --vnet-name $VNetName --resource-group $ResourceGroup --name $SubnetName 2>$null
    if (-not $subnetCheck) {
        throw "Subnet '$SubnetName' not found in virtual network '$VNetName' in resource group '$ResourceGroup'"
    }

    $subnetInfo = $subnetCheck | ConvertFrom-Json
    Write-Host "✓ Subnet '$SubnetName' found" -ForegroundColor Green

    # Display current Route Table association
    if ($subnetInfo.routeTable) {
        $currentRT = ($subnetInfo.routeTable.id -split '/')[-1]
        Write-Host "Current Route Table: $currentRT" -ForegroundColor Cyan
    } else {
        Write-Host "Current Route Table: None (using system routes)" -ForegroundColor Cyan
    }

    if ($RemoveRouteTable) {
        # Remove Route Table association
        if (-not $subnetInfo.routeTable) {
            Write-Host "ℹ Subnet does not have a Route Table association to remove" -ForegroundColor Blue
            Write-Host "Subnet will continue using Azure system routes" -ForegroundColor White
            exit 0
        }

        Write-Host "Removing Route Table association from subnet..." -ForegroundColor Yellow
        Write-Host "⚠ Subnet will revert to using Azure system routes" -ForegroundColor Yellow

        $azParams = @(
            'network', 'vnet', 'subnet', 'update',
            '--vnet-name', $VNetName,
            '--resource-group', $ResourceGroup,
            '--name', $SubnetName,
            '--remove', 'routeTable'
        )
    } else {
        # Associate Route Table
        if (-not $RouteTableName) {
            throw "RouteTableName is required when not removing Route Table association"
        }

        # Use provided Route Table resource group or default to subnet's resource group
        $rtRG = if ($RouteTableResourceGroup) { $RouteTableResourceGroup } else { $ResourceGroup }

        # Verify the Route Table exists
        Write-Host "Verifying Route Table exists..." -ForegroundColor Yellow
        $rtCheck = az network route-table show --name $RouteTableName --resource-group $rtRG 2>$null
        if (-not $rtCheck) {
            throw "Route Table '$RouteTableName' not found in resource group '$rtRG'"
        }

        $rtInfo = $rtCheck | ConvertFrom-Json
        Write-Host "✓ Route Table '$RouteTableName' found" -ForegroundColor Green

        if ($rtInfo.routes -and $rtInfo.routes.Count -gt 0) {
            Write-Host "Route Table contains $($rtInfo.routes.Count) custom route(s)" -ForegroundColor Cyan
        } else {
            Write-Host "Route Table contains no custom routes (system routes only)" -ForegroundColor Cyan
        }

        Write-Host "Associating Route Table with subnet..." -ForegroundColor Yellow

        $azParams = @(
            'network', 'vnet', 'subnet', 'update',
            '--vnet-name', $VNetName,
            '--resource-group', $ResourceGroup,
            '--name', $SubnetName,
            '--route-table', $RouteTableName
        )

        # Add Route Table resource group if different
        if ($RouteTableResourceGroup) {
            # Build full Route Table resource ID
            $rtId = "/subscriptions/$($azAccount.id)/resourceGroups/$RouteTableResourceGroup/providers/Microsoft.Network/routeTables/$RouteTableName"
            $azParams[-1] = $rtId
        }
    }

    Write-Host "VNet: $VNetName" -ForegroundColor Cyan
    Write-Host "Subnet: $SubnetName" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan

    if ($RemoveRouteTable) {
        Write-Host "Operation: Remove Route Table association" -ForegroundColor Yellow
    } else {
        Write-Host "Route Table: $RouteTableName" -ForegroundColor Cyan
        if ($RouteTableResourceGroup) {
            Write-Host "Route Table Resource Group: $RouteTableResourceGroup" -ForegroundColor Cyan
        }
        Write-Host "Operation: Associate Route Table" -ForegroundColor Green
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        if ($RemoveRouteTable) {
            Write-Host "✓ Route Table association removed successfully!" -ForegroundColor Green
            Write-Host "Subnet '$SubnetName' will now use Azure system routes" -ForegroundColor White
        } else {
            Write-Host "✓ Route Table associated successfully!" -ForegroundColor Green
            Write-Host "Route Table '$RouteTableName' is now controlling routing for subnet '$SubnetName'" -ForegroundColor White
        }

        # Parse and display updated subnet information
        try {
            $updatedSubnetInfo = $result | ConvertFrom-Json
            Write-Host "Updated Subnet Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($updatedSubnetInfo.name)" -ForegroundColor White
            Write-Host "  Address Prefix: $($updatedSubnetInfo.addressPrefix)" -ForegroundColor White

            if ($updatedSubnetInfo.routeTable) {
                Write-Host "  Route Table: $($updatedSubnetInfo.routeTable.id -split '/')[-1]" -ForegroundColor Green
            } else {
                Write-Host "  Route Table: None (system routes)" -ForegroundColor White
            }
        }
        catch {
            Write-Host "Operation completed successfully, but could not parse detailed information." -ForegroundColor Yellow
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
