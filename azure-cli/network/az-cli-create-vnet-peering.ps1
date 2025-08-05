<#
.SYNOPSIS
    Create Azure Virtual Network peering using Azure CLI.

.DESCRIPTION
    This script creates a peering connection between two Azure Virtual Networks using the Azure CLI.
    VNet peering allows resources in different virtual networks to communicate with each other.
    
    The script uses the Azure CLI command: az network vnet peering create

.PARAMETER VNetName
    The name of the source Virtual Network.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group containing the source VNet.

.PARAMETER PeeringName
    The name of the peering connection.

.PARAMETER RemoteVNetId
    The resource ID of the remote Virtual Network to peer with.

.PARAMETER AllowVNetAccess
    Allow access from the local virtual network to the remote virtual network.

.PARAMETER AllowForwardedTraffic
    Allow forwarded traffic from the remote virtual network to the local virtual network.

.PARAMETER AllowGatewayTransit
    Allow gateway transit for the remote virtual network.

.PARAMETER UseRemoteGateways
    Use remote virtual network's gateways or Route Server.

.EXAMPLE
    .\az-cli-create-vnet-peering.ps1 -VNetName "hub-vnet" -ResourceGroup "hub-rg" -PeeringName "hub-to-spoke1" -RemoteVNetId "/subscriptions/.../resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke1-vnet"
    
    Creates a basic VNet peering connection.

.EXAMPLE
    .\az-cli-create-vnet-peering.ps1 -VNetName "hub-vnet" -ResourceGroup "hub-rg" -PeeringName "hub-to-spoke1" -RemoteVNetId "/subscriptions/.../resourceGroups/spoke-rg/providers/Microsoft.Network/virtualNetworks/spoke1-vnet" -AllowGatewayTransit
    
    Creates a VNet peering with gateway transit enabled (hub-spoke topology).

.EXAMPLE
    .\az-cli-create-vnet-peering.ps1 -VNetName "spoke1-vnet" -ResourceGroup "spoke-rg" -PeeringName "spoke1-to-hub" -RemoteVNetId "/subscriptions/.../resourceGroups/hub-rg/providers/Microsoft.Network/virtualNetworks/hub-vnet" -UseRemoteGateways
    
    Creates a spoke-to-hub peering that uses the hub's gateways.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: VNet peering is not transitive. You need to create peering in both directions for bidirectional communication.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/vnet/peering

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-peering-overview

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the source Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [string]$VNetName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the peering connection")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [string]$PeeringName,

    [Parameter(Mandatory = $true, HelpMessage = "The resource ID of the remote Virtual Network")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^/subscriptions/[0-9a-f-]+/resourceGroups/.+/providers/Microsoft\.Network/virtualNetworks/.+$', ErrorMessage = "Remote VNet ID must be a valid Azure resource ID")]
    [string]$RemoteVNetId,

    [Parameter(HelpMessage = "Allow access from local VNet to remote VNet")]
    [switch]$AllowVNetAccess,

    [Parameter(HelpMessage = "Allow forwarded traffic from remote VNet")]
    [switch]$AllowForwardedTraffic,

    [Parameter(HelpMessage = "Allow gateway transit for remote VNet")]
    [switch]$AllowGatewayTransit,

    [Parameter(HelpMessage = "Use remote VNet's gateways")]
    [switch]$UseRemoteGateways
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

    # Verify the source VNet exists
    Write-Host "Verifying source Virtual Network exists..." -ForegroundColor Yellow
    $vnetCheck = az network vnet show --name $VNetName --resource-group $ResourceGroup 2>$null
    if (-not $vnetCheck) {
        throw "Virtual network '$VNetName' not found in resource group '$ResourceGroup'"
    }
    Write-Host "✓ Source Virtual Network '$VNetName' found" -ForegroundColor Green

    # Validate gateway transit and remote gateway usage
    if ($AllowGatewayTransit -and $UseRemoteGateways) {
        throw "Cannot use both AllowGatewayTransit and UseRemoteGateways on the same peering. These are mutually exclusive."
    }

    # Extract remote VNet name from resource ID for display
    $remoteVNetName = ($RemoteVNetId -split '/')[-1]
    $remoteRG = ($RemoteVNetId -split '/')[-5]

    # Build Azure CLI command parameters
    $azParams = @(
        'network', 'vnet', 'peering', 'create',
        '--vnet-name', $VNetName,
        '--resource-group', $ResourceGroup,
        '--name', $PeeringName,
        '--remote-vnet', $RemoteVNetId
    )

    # Add optional parameters (defaults are true for access, false for others)
    if ($AllowVNetAccess) { 
        $azParams += '--allow-vnet-access', 'true' 
    } else {
        $azParams += '--allow-vnet-access', 'false'
    }
    
    if ($AllowForwardedTraffic) { 
        $azParams += '--allow-forwarded-traffic', 'true' 
    }
    
    if ($AllowGatewayTransit) { 
        $azParams += '--allow-gateway-transit', 'true' 
    }
    
    if ($UseRemoteGateways) { 
        $azParams += '--use-remote-gateways', 'true' 
    }

    Write-Host "Creating VNet peering..." -ForegroundColor Yellow
    Write-Host "Source VNet: $VNetName (Resource Group: $ResourceGroup)" -ForegroundColor Cyan
    Write-Host "Remote VNet: $remoteVNetName (Resource Group: $remoteRG)" -ForegroundColor Cyan
    Write-Host "Peering Name: $PeeringName" -ForegroundColor Cyan
    Write-Host "Allow VNet Access: $(if ($AllowVNetAccess) { 'Yes' } else { 'No' })" -ForegroundColor Cyan
    
    if ($AllowForwardedTraffic) {
        Write-Host "Allow Forwarded Traffic: Yes" -ForegroundColor Green
    }
    if ($AllowGatewayTransit) {
        Write-Host "Allow Gateway Transit: Yes" -ForegroundColor Green
    }
    if ($UseRemoteGateways) {
        Write-Host "Use Remote Gateways: Yes" -ForegroundColor Green
    }

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ VNet peering created successfully!" -ForegroundColor Green
        
        # Parse and display peering information
        try {
            $peeringInfo = $result | ConvertFrom-Json
            Write-Host "Peering Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($peeringInfo.name)" -ForegroundColor White
            Write-Host "  Peering State: $($peeringInfo.peeringState)" -ForegroundColor White
            Write-Host "  Provisioning State: $($peeringInfo.provisioningState)" -ForegroundColor White
            Write-Host "  Allow VNet Access: $($peeringInfo.allowVirtualNetworkAccess)" -ForegroundColor White
            Write-Host "  Allow Forwarded Traffic: $($peeringInfo.allowForwardedTraffic)" -ForegroundColor White
            Write-Host "  Allow Gateway Transit: $($peeringInfo.allowGatewayTransit)" -ForegroundColor White
            Write-Host "  Use Remote Gateways: $($peeringInfo.useRemoteGateways)" -ForegroundColor White
            
            if ($peeringInfo.peeringState -eq "Initiated") {
                Write-Host "" -ForegroundColor Yellow
                Write-Host "⚠ Note: Peering state is 'Initiated'. You need to create the reverse peering" -ForegroundColor Yellow
                Write-Host "  from the remote VNet for bidirectional communication." -ForegroundColor Yellow
            } elseif ($peeringInfo.peeringState -eq "Connected") {
                Write-Host "" -ForegroundColor Green
                Write-Host "✓ Peering is fully connected and operational!" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "Peering created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create VNet peering" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
