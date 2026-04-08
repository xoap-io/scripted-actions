<#
.SYNOPSIS
    Delete an Azure Virtual Network peering using Azure CLI.

.DESCRIPTION
    This script deletes a peering connection from an Azure Virtual Network using the Azure CLI.
    Includes safety checks and confirmation prompts to prevent accidental deletion.

    The script uses the Azure CLI command: az network vnet peering delete

.PARAMETER VNetName
    The name of the source Virtual Network containing the peering.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the source VNet.

.PARAMETER PeeringName
    The name of the peering connection to delete.

.PARAMETER Force
    Force deletion without confirmation prompts.

.EXAMPLE
    .\az-cli-delete-vnet-peering.ps1 -VNetName "hub-vnet" -ResourceGroup "hub-rg" -PeeringName "hub-to-spoke1"

    Deletes a VNet peering connection with confirmation.

.EXAMPLE
    .\az-cli-delete-vnet-peering.ps1 -VNetName "hub-vnet" -ResourceGroup "hub-rg" -PeeringName "hub-to-spoke1" -Force

    Forces deletion without confirmation prompts.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
    Note: This only deletes peering from one direction. Delete the reverse peering separately if needed.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet/peering

.COMPONENT
    Azure CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the source Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [string]$VNetName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the peering connection to delete")]
    [ValidateNotNullOrEmpty()]
    [string]$PeeringName,

    [Parameter(HelpMessage = "Force deletion without confirmation")]
    [switch]$Force
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

    # Verify the peering exists
    Write-Host "Verifying VNet peering exists..." -ForegroundColor Yellow
    $peeringCheck = az network vnet peering show --vnet-name $VNetName --resource-group $ResourceGroup --name $PeeringName 2>$null
    if (-not $peeringCheck) {
        throw "VNet peering '$PeeringName' not found in virtual network '$VNetName' in resource group '$ResourceGroup'"
    }

    $peeringInfo = $peeringCheck | ConvertFrom-Json
    Write-Host "✓ VNet peering '$PeeringName' found" -ForegroundColor Green

    # Extract remote VNet information
    $remoteVNetId = $peeringInfo.remoteVirtualNetwork.id
    $remoteVNetName = ($remoteVNetId -split '/')[-1]
    $remoteRG = ($remoteVNetId -split '/')[-5]

    # Display peering details
    Write-Host "Peering Details:" -ForegroundColor Cyan
    Write-Host "  Local VNet: $VNetName" -ForegroundColor White
    Write-Host "  Remote VNet: $remoteVNetName (RG: $remoteRG)" -ForegroundColor White
    Write-Host "  Peering State: $($peeringInfo.peeringState)" -ForegroundColor White
    Write-Host "  Allow VNet Access: $($peeringInfo.allowVirtualNetworkAccess)" -ForegroundColor White
    Write-Host "  Allow Forwarded Traffic: $($peeringInfo.allowForwardedTraffic)" -ForegroundColor White
    Write-Host "  Allow Gateway Transit: $($peeringInfo.allowGatewayTransit)" -ForegroundColor White
    Write-Host "  Use Remote Gateways: $($peeringInfo.useRemoteGateways)" -ForegroundColor White

    # Confirmation prompt unless forced
    if (-not $Force) {
        Write-Host "" -ForegroundColor White
        Write-Host "⚠ WARNING: This will permanently delete the VNet peering '$PeeringName'" -ForegroundColor Red
        Write-Host "This will break connectivity between:" -ForegroundColor Yellow
        Write-Host "  Source: $VNetName (Resource Group: $ResourceGroup)" -ForegroundColor Yellow
        Write-Host "  Remote: $remoteVNetName (Resource Group: $remoteRG)" -ForegroundColor Yellow
        Write-Host "" -ForegroundColor White
        Write-Host "Note: This only deletes peering from the source VNet." -ForegroundColor Blue
        Write-Host "The reverse peering (if it exists) will remain and should be deleted separately." -ForegroundColor Blue
        Write-Host "" -ForegroundColor White

        $confirmation = Read-Host "Are you sure you want to delete this peering? (yes/no)"
        if ($confirmation -ne "yes") {
            Write-Host "Deletion cancelled by user." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'vnet', 'peering', 'delete',
        '--vnet-name', $VNetName,
        '--resource-group', $ResourceGroup,
        '--name', $PeeringName
    )

    Write-Host "Deleting VNet peering..." -ForegroundColor Yellow
    Write-Host "VNet: $VNetName" -ForegroundColor Cyan
    Write-Host "Peering: $PeeringName" -ForegroundColor Cyan
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan

    # Execute Azure CLI command
    $result = & az @azParams 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ VNet peering deleted successfully!" -ForegroundColor Green
        Write-Host "Peering '$PeeringName' has been removed from virtual network '$VNetName'" -ForegroundColor White
        Write-Host "" -ForegroundColor White
        Write-Host "Important reminders:" -ForegroundColor Yellow
        Write-Host "• Connectivity between the VNets is now broken from this direction" -ForegroundColor White
        Write-Host "• Check if reverse peering exists in the remote VNet and delete it if needed" -ForegroundColor White
        Write-Host "• Any resources depending on cross-VNet connectivity may be affected" -ForegroundColor White
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
