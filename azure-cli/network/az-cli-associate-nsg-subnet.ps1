<#
.SYNOPSIS
    Associate a Network Security Group with an Azure subnet using Azure CLI.

.DESCRIPTION
    This script associates an existing Network Security Group with a subnet in an Azure Virtual Network using the Azure CLI.
    Can also be used to remove NSG association by specifying no NSG.

    The script uses the Azure CLI command: az network vnet subnet update

.PARAMETER VNetName
    The name of the existing Azure Virtual Network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the virtual network.

.PARAMETER SubnetName
    The name of the subnet to update.

.PARAMETER NSGName
    The name of the Network Security Group to associate (leave empty to remove association).

.PARAMETER NSGResourceGroup
    The resource group containing the NSG (if different from subnet's resource group).

.PARAMETER RemoveNSG
    Remove the current NSG association from the subnet.

.EXAMPLE
    .\az-cli-associate-nsg-subnet.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "web-subnet" -NSGName "web-nsg"

    Associates a Network Security Group with a subnet.

.EXAMPLE
    .\az-cli-associate-nsg-subnet.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "web-subnet" -NSGName "web-nsg" -NSGResourceGroup "security-rg"

    Associates an NSG from a different resource group.

.EXAMPLE
    .\az-cli-associate-nsg-subnet.ps1 -VNetName "MyVNet" -ResourceGroup "MyRG" -SubnetName "web-subnet" -RemoveNSG

    Removes the NSG association from a subnet.

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

    [Parameter(ParameterSetName = 'Associate', HelpMessage = "The name of the Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [string]$NSGName,

    [Parameter(ParameterSetName = 'Associate', HelpMessage = "The resource group containing the NSG")]
    [string]$NSGResourceGroup,

    [Parameter(ParameterSetName = 'Remove', HelpMessage = "Remove the NSG association")]
    [switch]$RemoveNSG
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

    # Display current NSG association
    if ($subnetInfo.networkSecurityGroup) {
        $currentNSG = ($subnetInfo.networkSecurityGroup.id -split '/')[-1]
        Write-Host "Current NSG: $currentNSG" -ForegroundColor Cyan
    } else {
        Write-Host "Current NSG: None" -ForegroundColor Cyan
    }

    if ($RemoveNSG) {
        # Remove NSG association
        if (-not $subnetInfo.networkSecurityGroup) {
            Write-Host "ℹ Subnet does not have an NSG association to remove" -ForegroundColor Blue
            exit 0
        }

        Write-Host "Removing NSG association from subnet..." -ForegroundColor Yellow

        $azParams = @(
            'network', 'vnet', 'subnet', 'update',
            '--vnet-name', $VNetName,
            '--resource-group', $ResourceGroup,
            '--name', $SubnetName,
            '--remove', 'networkSecurityGroup'
        )
    } else {
        # Associate NSG
        if (-not $NSGName) {
            throw "NSGName is required when not removing NSG association"
        }

        # Use provided NSG resource group or default to subnet's resource group
        $nsgRG = if ($NSGResourceGroup) { $NSGResourceGroup } else { $ResourceGroup }

        # Verify the NSG exists
        Write-Host "Verifying Network Security Group exists..." -ForegroundColor Yellow
        $nsgCheck = az network nsg show --name $NSGName --resource-group $nsgRG 2>$null
        if (-not $nsgCheck) {
            throw "Network Security Group '$NSGName' not found in resource group '$nsgRG'"
        }
        Write-Host "✓ Network Security Group '$NSGName' found" -ForegroundColor Green

        Write-Host "Associating NSG with subnet..." -ForegroundColor Yellow

        $azParams = @(
            'network', 'vnet', 'subnet', 'update',
            '--vnet-name', $VNetName,
            '--resource-group', $ResourceGroup,
            '--name', $SubnetName,
            '--network-security-group', $NSGName
        )

        # Add NSG resource group if different
        if ($NSGResourceGroup) {
            # Build full NSG resource ID
            $nsgId = "/subscriptions/$($azAccount.id)/resourceGroups/$NSGResourceGroup/providers/Microsoft.Network/networkSecurityGroups/$NSGName"
            $azParams[-1] = $nsgId
        }
    }

    Write-Host "VNet: $VNetName" -ForegroundColor Cyan
    Write-Host "Subnet: $SubnetName" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan

    if ($RemoveNSG) {
        Write-Host "Operation: Remove NSG association" -ForegroundColor Yellow
    } else {
        Write-Host "NSG: $NSGName" -ForegroundColor Cyan
        if ($NSGResourceGroup) {
            Write-Host "NSG Resource Group: $NSGResourceGroup" -ForegroundColor Cyan
        }
        Write-Host "Operation: Associate NSG" -ForegroundColor Green
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        if ($RemoveNSG) {
            Write-Host "✓ NSG association removed successfully!" -ForegroundColor Green
            Write-Host "Subnet '$SubnetName' no longer has an associated Network Security Group" -ForegroundColor White
        } else {
            Write-Host "✓ NSG associated successfully!" -ForegroundColor Green
            Write-Host "Network Security Group '$NSGName' is now associated with subnet '$SubnetName'" -ForegroundColor White
        }

        # Parse and display updated subnet information
        try {
            $updatedSubnetInfo = $result | ConvertFrom-Json
            Write-Host "Updated Subnet Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($updatedSubnetInfo.name)" -ForegroundColor White
            Write-Host "  Address Prefix: $($updatedSubnetInfo.addressPrefix)" -ForegroundColor White

            if ($updatedSubnetInfo.networkSecurityGroup) {
                Write-Host "  Network Security Group: $(($updatedSubnetInfo.networkSecurityGroup.id -split '/')[-1])" -ForegroundColor Green
            } else {
                Write-Host "  Network Security Group: None" -ForegroundColor White
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
