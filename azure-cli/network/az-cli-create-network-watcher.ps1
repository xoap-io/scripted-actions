<#
.SYNOPSIS
    Create an Azure Network Watcher using Azure CLI.

.DESCRIPTION
    This script creates an Azure Network Watcher using the Azure CLI.
    Network Watcher provides monitoring, diagnostics, and analytics for Azure network resources.
    Includes capabilities for connection monitoring, packet capture, flow logs, and network topology visualization.

    The script uses the Azure CLI command: az network watcher configure

.PARAMETER Location
    The Azure region where Network Watcher will be enabled.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group for Network Watcher resources.

.PARAMETER StorageAccountName
    The name of the storage account for Network Watcher data (optional).

.PARAMETER StorageAccountResourceGroup
    The resource group containing the storage account.

.PARAMETER EnableFlowLogs
    Enable NSG flow logs after creating Network Watcher.

.PARAMETER FlowLogNSGName
    The name of the NSG to enable flow logs for.

.PARAMETER FlowLogNSGResourceGroup
    The resource group containing the NSG for flow logs.

.PARAMETER RetentionDays
    The number of days to retain flow log data.

.PARAMETER Tags
    Tags to apply to Network Watcher resources as JSON string.

.EXAMPLE
    .\az-cli-create-network-watcher.ps1 -Location "East US" -ResourceGroup "NetworkWatcherRG"

    Creates Network Watcher in the specified region with automatic resource group.

.EXAMPLE
    .\az-cli-create-network-watcher.ps1 -Location "East US" -ResourceGroup "NetworkWatcherRG" -StorageAccountName "nwstorage" -EnableFlowLogs -FlowLogNSGName "web-nsg" -FlowLogNSGResourceGroup "prod-rg"

    Creates Network Watcher and enables flow logs for a specific NSG.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI
    Note: Network Watcher is automatically available in most regions but can be explicitly configured.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/watcher

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The Azure region for Network Watcher")]
    [ValidateSet(
        "East US", "East US 2", "West US", "West US 2", "West US 3", "Central US", "North Central US", "South Central US",
        "Canada Central", "Canada East", "Brazil South", "North Europe", "West Europe", "UK South", "UK West",
        "France Central", "Germany West Central", "Switzerland North", "Norway East", "Sweden Central",
        "Australia East", "Australia Southeast", "Southeast Asia", "East Asia", "Japan East", "Japan West",
        "Korea Central", "Central India", "South India", "West India", "UAE North", "South Africa North"
    )]
    [string]$Location,

    [Parameter(HelpMessage = "The resource group for Network Watcher")]
    [string]$ResourceGroup = "NetworkWatcherRG",

    [Parameter(HelpMessage = "Storage account name for Network Watcher data")]
    [ValidateLength(3, 24)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$StorageAccountName,

    [Parameter(HelpMessage = "Resource group for the storage account")]
    [string]$StorageAccountResourceGroup,

    [Parameter(HelpMessage = "Enable NSG flow logs")]
    [switch]$EnableFlowLogs,

    [Parameter(HelpMessage = "NSG name to enable flow logs for")]
    [string]$FlowLogNSGName,

    [Parameter(HelpMessage = "Resource group containing the NSG")]
    [string]$FlowLogNSGResourceGroup,

    [Parameter(HelpMessage = "Flow log retention period in days")]
    [ValidateRange(0, 365)]
    [int]$RetentionDays = 7,

    [Parameter(HelpMessage = "Tags as JSON string")]
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

    # Check if Network Watcher is already configured in the region
    Write-Host "Checking Network Watcher status..." -ForegroundColor Yellow
    $nwList = az network watcher list 2>$null | ConvertFrom-Json
    $existingNW = $nwList | Where-Object { $_.location -eq $Location.Replace(' ', '').ToLower() }

    if ($existingNW) {
        Write-Host "ℹ Network Watcher already exists in $Location" -ForegroundColor Blue
        Write-Host "  Name: $($existingNW.name)" -ForegroundColor White
        Write-Host "  Resource Group: $($existingNW.resourceGroup)" -ForegroundColor White
        Write-Host "  Provisioning State: $($existingNW.provisioningState)" -ForegroundColor White
        $networkWatcherName = $existingNW.name
        $actualResourceGroup = $existingNW.resourceGroup
    } else {
        # Create or configure Network Watcher
        Write-Host "Configuring Network Watcher for $Location..." -ForegroundColor Yellow

        # Create resource group if it doesn't exist
        $rgExists = az group show --name $ResourceGroup 2>$null
        if (-not $rgExists) {
            Write-Host "Creating resource group '$ResourceGroup'..." -ForegroundColor Yellow
            az group create --name $ResourceGroup --location $Location | Out-Null
            Write-Host "✓ Resource group created" -ForegroundColor Green
        }

        # Configure Network Watcher
        $azParams = @(
            'network', 'watcher', 'configure',
            '--locations', $Location,
            '--resource-group', $ResourceGroup,
            '--enabled', 'true'
        )

        $result = & az @azParams 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Network Watcher configured successfully" -ForegroundColor Green
            $networkWatcherName = "NetworkWatcher_$($Location.Replace(' ', '').ToLower())"
            $actualResourceGroup = $ResourceGroup
        } else {
            throw "Failed to configure Network Watcher: $($result -join "`n")"
        }
    }

    # Create storage account if specified and flow logs are enabled
    if ($EnableFlowLogs -and $StorageAccountName) {
        $storageRG = if ($StorageAccountResourceGroup) { $StorageAccountResourceGroup } else { $actualResourceGroup }

        Write-Host "Checking storage account for flow logs..." -ForegroundColor Yellow
        $storageExists = az storage account show --name $StorageAccountName --resource-group $storageRG 2>$null

        if (-not $storageExists) {
            Write-Host "Creating storage account for flow logs..." -ForegroundColor Yellow
            $null = az storage account create `
                --name $StorageAccountName `
                --resource-group $storageRG `
                --location $Location `
                --sku Standard_LRS `
                --kind StorageV2 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Storage account created" -ForegroundColor Green
            } else {
                Write-Host "⚠ Warning: Failed to create storage account. Flow logs may not work properly." -ForegroundColor Yellow
            }
        } else {
            Write-Host "✓ Storage account exists" -ForegroundColor Green
        }
    }

    # Enable flow logs if requested
    if ($EnableFlowLogs -and $FlowLogNSGName) {
        Write-Host "Configuring NSG flow logs..." -ForegroundColor Yellow

        $nsgRG = if ($FlowLogNSGResourceGroup) { $FlowLogNSGResourceGroup } else { $actualResourceGroup }

        # Verify NSG exists
        $nsgExists = az network nsg show --name $FlowLogNSGName --resource-group $nsgRG 2>$null
        if (-not $nsgExists) {
            Write-Host "⚠ Warning: NSG '$FlowLogNSGName' not found in resource group '$nsgRG'. Skipping flow log configuration." -ForegroundColor Yellow
        } else {
            $flowLogParams = @(
                'network', 'watcher', 'flow-log', 'create',
                '--name', "$FlowLogNSGName-flowlog",
                '--resource-group', $actualResourceGroup,
                '--nsg', $FlowLogNSGName,
                '--storage-account', $StorageAccountName,
                '--enabled', 'true',
                '--retention', $RetentionDays.ToString(),
                '--log-format', 'JSON',
                '--log-version', '2'
            )

            $flowLogResult = & az @flowLogParams 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ NSG flow logs configured" -ForegroundColor Green
            } else {
                Write-Host "⚠ Warning: Failed to configure flow logs: $($flowLogResult -join "`n")" -ForegroundColor Yellow
            }
        }
    }

    # Display Network Watcher information
    $nwInfo = az network watcher show --name $networkWatcherName --resource-group $actualResourceGroup | ConvertFrom-Json

    Write-Host "Network Watcher Configuration:" -ForegroundColor Cyan
    Write-Host "  Name: $($nwInfo.name)" -ForegroundColor White
    Write-Host "  Resource Group: $($nwInfo.resourceGroup)" -ForegroundColor White
    Write-Host "  Location: $($nwInfo.location)" -ForegroundColor White
    Write-Host "  Provisioning State: $($nwInfo.provisioningState)" -ForegroundColor White

    if ($EnableFlowLogs) {
        Write-Host "  Flow Logs: Enabled" -ForegroundColor Green
        if ($StorageAccountName) {
            Write-Host "  Storage Account: $StorageAccountName" -ForegroundColor White
        }
        if ($FlowLogNSGName) {
            Write-Host "  Monitored NSG: $FlowLogNSGName" -ForegroundColor White
        }
        Write-Host "  Retention Days: $RetentionDays" -ForegroundColor White
    }

    Write-Host "" -ForegroundColor White
    Write-Host "✓ Network Watcher setup completed!" -ForegroundColor Green
    Write-Host "" -ForegroundColor White
    Write-Host "Available Network Watcher capabilities:" -ForegroundColor Yellow
    Write-Host "• Connection Monitor - Monitor connectivity between resources" -ForegroundColor White
    Write-Host "• Packet Capture - Capture network traffic for analysis" -ForegroundColor White
    Write-Host "• IP Flow Verify - Test network security group rules" -ForegroundColor White
    Write-Host "• Next Hop - Determine next hop for traffic routing" -ForegroundColor White
    Write-Host "• Security Group View - View effective security rules" -ForegroundColor White
    Write-Host "• Network Topology - Visualize network architecture" -ForegroundColor White
    if ($EnableFlowLogs) {
        Write-Host "• Flow Logs - Analyze network traffic patterns" -ForegroundColor Green
    }

    Write-Host "" -ForegroundColor White
    Write-Host "Common Network Watcher commands:" -ForegroundColor Cyan
    Write-Host "# Test connectivity" -ForegroundColor Gray
    Write-Host "az network watcher test-connectivity --source-resource <vm-id> --dest-resource <vm-id>" -ForegroundColor White
    Write-Host "# Check IP flow" -ForegroundColor Gray
    Write-Host "az network watcher test-ip-flow --vm <vm-name> --nic <nic-name> --direction Inbound --protocol TCP --local 10.0.0.4:22 --remote 0.0.0.0:*" -ForegroundColor White
    Write-Host "# View topology" -ForegroundColor Gray
    Write-Host "az network watcher show-topology --resource-group <rg-name>" -ForegroundColor White
}
catch {
    Write-Host "✗ Failed to configure Network Watcher" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
