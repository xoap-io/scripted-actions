<#
.SYNOPSIS
    Delete an Azure Network Security Group using Azure CLI.

.DESCRIPTION
    This script deletes an Azure Network Security Group using the Azure CLI.
    Includes safety checks to verify the NSG is not associated with any resources
    and provides confirmation prompts to prevent accidental deletion.

    The script uses the Azure CLI command: az network nsg delete

.PARAMETER NSGName
    The name of the Network Security Group to delete.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the NSG.

.PARAMETER Force
    Force deletion without confirmation prompts.

.PARAMETER SkipAssociationCheck
    Skip checking for subnet and network interface associations.

.EXAMPLE
    .\az-cli-delete-network-security-group.ps1 -NSGName "web-nsg" -ResourceGroup "prod-rg"

    Deletes a Network Security Group with safety checks and confirmation.

.EXAMPLE
    .\az-cli-delete-network-security-group.ps1 -NSGName "web-nsg" -ResourceGroup "prod-rg" -Force

    Forces deletion without confirmation prompts but still checks associations.

.EXAMPLE
    .\az-cli-delete-network-security-group.ps1 -NSGName "web-nsg" -ResourceGroup "prod-rg" -Force -SkipAssociationCheck

    Forces deletion without any safety checks or confirmations.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Warning: Deleting an NSG while it's associated with resources may cause network connectivity issues.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/nsg

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Network Security Group to delete")]
    [ValidateNotNullOrEmpty()]
    [string]$NSGName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Force deletion without confirmation")]
    [switch]$Force,

    [Parameter(HelpMessage = "Skip checking for subnet and network interface associations")]
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

    # Verify the NSG exists
    Write-Host "Verifying Network Security Group exists..." -ForegroundColor Yellow
    $nsgCheck = az network nsg show --name $NSGName --resource-group $ResourceGroup 2>$null
    if (-not $nsgCheck) {
        throw "Network Security Group '$NSGName' not found in resource group '$ResourceGroup'"
    }

    $nsgInfo = $nsgCheck | ConvertFrom-Json
    Write-Host "✓ Network Security Group '$NSGName' found" -ForegroundColor Green

    # Display NSG details
    Write-Host "Network Security Group Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($nsgInfo.name)" -ForegroundColor White
    Write-Host "  Location: $($nsgInfo.location)" -ForegroundColor White
    Write-Host "  Resource Group: $($nsgInfo.resourceGroup)" -ForegroundColor White
    Write-Host "  Security Rules: $($nsgInfo.securityRules.Count) custom rules" -ForegroundColor White
    Write-Host "  Default Security Rules: $($nsgInfo.defaultSecurityRules.Count) default rules" -ForegroundColor White

    # Check for associations unless skipped
    if (-not $SkipAssociationCheck) {
        Write-Host "Checking for resource associations..." -ForegroundColor Yellow

        $hasAssociations = $false
        $associationDetails = @()

        # Check subnet associations
        if ($nsgInfo.subnets -and $nsgInfo.subnets.Count -gt 0) {
            $hasAssociations = $true
            foreach ($subnet in $nsgInfo.subnets) {
                $subnetName = ($subnet.id -split '/')[-1]
                $vnetName = ($subnet.id -split '/')[-3]
                $subnetRG = ($subnet.id -split '/')[-7]
                $associationDetails += "  • Subnet: $subnetName (VNet: $vnetName, RG: $subnetRG)"
            }
        }

        # Check network interface associations
        if ($nsgInfo.networkInterfaces -and $nsgInfo.networkInterfaces.Count -gt 0) {
            $hasAssociations = $true
            foreach ($nic in $nsgInfo.networkInterfaces) {
                $nicName = ($nic.id -split '/')[-1]
                $nicRG = ($nic.id -split '/')[-5]
                $associationDetails += "  • Network Interface: $nicName (RG: $nicRG)"
            }
        }

        if ($hasAssociations) {
            Write-Host "⚠ WARNING: NSG has active associations!" -ForegroundColor Red
            Write-Host "Associated Resources:" -ForegroundColor Yellow
            $associationDetails | ForEach-Object { Write-Host $_ -ForegroundColor White }
            Write-Host "" -ForegroundColor White
            Write-Host "Deleting this NSG will remove network security from these resources!" -ForegroundColor Red

            if (-not $Force) {
                Write-Host "" -ForegroundColor White
                $confirmation = Read-Host "Do you want to continue with deletion despite associations? (yes/no)"
                if ($confirmation -ne "yes") {
                    Write-Host "Deletion cancelled due to resource associations." -ForegroundColor Yellow
                    Write-Host "To proceed, first remove the NSG from all associated resources or use -Force parameter." -ForegroundColor Blue
                    exit 0
                }
            }
        } else {
            Write-Host "✓ No resource associations found" -ForegroundColor Green
        }
    } else {
        Write-Host "⚠ Skipping association checks as requested" -ForegroundColor Yellow
    }

    # Final confirmation prompt unless forced
    if (-not $Force) {
        Write-Host "" -ForegroundColor White
        Write-Host "⚠ WARNING: This will permanently delete the Network Security Group '$NSGName'" -ForegroundColor Red
        Write-Host "This action cannot be undone!" -ForegroundColor Red
        Write-Host "" -ForegroundColor White

        $confirmation = Read-Host "Are you sure you want to delete this NSG? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "Deletion cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'nsg', 'delete',
        '--name', $NSGName,
        '--resource-group', $ResourceGroup,
        '--yes'  # Skip confirmation in Azure CLI
    )

    Write-Host "Deleting Network Security Group..." -ForegroundColor Yellow
    Write-Host "Name: $NSGName" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Network Security Group deleted successfully!" -ForegroundColor Green
        Write-Host "NSG '$NSGName' has been permanently removed from resource group '$ResourceGroup'" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "Important reminders:" -ForegroundColor Yellow
        Write-Host "• Any resources that were protected by this NSG now have default network security" -ForegroundColor White
        Write-Host "• Review network security for previously associated resources" -ForegroundColor White
        Write-Host "• Consider applying alternative NSGs if needed" -ForegroundColor White
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to delete Network Security Group" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
