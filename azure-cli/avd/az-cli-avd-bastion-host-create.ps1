<#
.SYNOPSIS
    Create an Azure Bastion Host with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Bastion Host using Azure CLI.
    It includes validation for Azure CLI availability and login status.

.PARAMETER BastionName
    The name of the Azure Bastion Host.

.PARAMETER PublicIpAddress
    The name or ID of the public IP address to associate with the Bastion Host.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER VnetName
    The name of the Azure Virtual Network.

.PARAMETER Location
    The Azure region for the Bastion Host.

.PARAMETER DisableCopyPaste
    Disable copy and paste functionality.

.PARAMETER EnableIpConnect
    Enable IP Connect feature.

.PARAMETER EnableTunneling
    Enable tunneling feature.

.PARAMETER FileCopy
    Enable file copy feature.

.PARAMETER Kerberos
    Enable Kerberos authentication.

.PARAMETER NoWait
    Do not wait for the long-running operation to finish.

.PARAMETER ScaleUnits
    The number of scale units for the Bastion Host (2-50).

.PARAMETER SessionRecording
    Enable session recording feature.

.PARAMETER ShareableLink
    Enable shareable link feature.

.PARAMETER Sku
    The SKU of the Bastion Host. Valid values: 'Basic', 'Standard'

.PARAMETER Tags
    Optional tags in the format 'key1=value1 key2=value2'.

.PARAMETER Zones
    Availability zones for the Bastion Host (space-delimited).

.EXAMPLE
    .\az-cli-avd-bastion-host-create.ps1 -BastionName "MyBastion" -PublicIpAddress "MyPublicIP" -ResourceGroup "MyResourceGroup" -VnetName "MyVnet" -Location "eastus"

.EXAMPLE
    .\az-cli-avd-bastion-host-create.ps1 -BastionName "MyBastion" -PublicIpAddress "MyPublicIP" -ResourceGroup "MyRG" -VnetName "MyVnet" -Location "westus2" -Sku "Standard" -EnableTunneling -FileCopy

.EXAMPLE
    .\az-cli-avd-bastion-host-create.ps1 -BastionName "MyBastion" -PublicIpAddress "/subscriptions/sub-id/resourceGroups/rg/providers/Microsoft.Network/publicIPAddresses/ip" -ResourceGroup "MyRG" -VnetName "MyVnet" -Location "eastus2" -ScaleUnits 5

.LINK
    https://learn.microsoft.com/en-us/cli/azure/network/bastion

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BastionName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpAddress,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory)]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral'
    )]
    [string]$Location,

    [Parameter()]
    [switch]$DisableCopyPaste,

    [Parameter()]
    [switch]$EnableIpConnect,

    [Parameter()]
    [switch]$EnableTunneling,

    [Parameter()]
    [switch]$FileCopy,

    [Parameter()]
    [switch]$Kerberos,

    [Parameter()]
    [switch]$NoWait,

    [Parameter()]
    [ValidateRange(2, 50)]
    [int]$ScaleUnits,

    [Parameter()]
    [switch]$SessionRecording,

    [Parameter()]
    [switch]$ShareableLink,

    [Parameter()]
    [ValidateSet('Basic', 'Standard')]
    [string]$Sku,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Tags,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Zones
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating Azure CLI is available..." -ForegroundColor Cyan
    $azVersion = az version --output tsv --query '"azure-cli"' 2>$null
    if (-not $azVersion) {
        throw "Azure CLI is not installed or not available in PATH"
    }

    Write-Host "Checking Azure CLI login status..." -ForegroundColor Cyan
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Not logged in to Azure CLI. Please run 'az login' first"
    }
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green

    Write-Host "Checking if Resource Group exists..." -ForegroundColor Cyan
    $resourceGroupExists = az group show --name $ResourceGroup --output json 2>$null
    if (-not $resourceGroupExists) {
        throw "Resource Group '$ResourceGroup' not found"
    }

    Write-Host "Checking if Virtual Network exists..." -ForegroundColor Cyan
    $vnetExists = az network vnet show --name $VnetName --resource-group $ResourceGroup --output json 2>$null
    if (-not $vnetExists) {
        throw "Virtual Network '$VnetName' not found in resource group '$ResourceGroup'"
    }

    Write-Host "Checking if Public IP exists..." -ForegroundColor Cyan
    # Check if it's a resource ID or just a name
    if ($PublicIpAddress -like "/subscriptions/*") {
        $publicIpExists = az network public-ip show --ids $PublicIpAddress --output json 2>$null
    } else {
        $publicIpExists = az network public-ip show --name $PublicIpAddress --resource-group $ResourceGroup --output json 2>$null
    }
    if (-not $publicIpExists) {
        throw "Public IP '$PublicIpAddress' not found"
    }

    Write-Host "Checking if Bastion Host already exists..." -ForegroundColor Cyan
    $existingBastion = az network bastion show --name $BastionName --resource-group $ResourceGroup --output json 2>$null
    if ($existingBastion) {
        $bastionData = $existingBastion | ConvertFrom-Json
        Write-Warning "Bastion Host '$BastionName' already exists in resource group '$ResourceGroup'"
        Write-Host "  Location: $($bastionData.location)" -ForegroundColor Yellow
        Write-Host "  SKU: $($bastionData.sku.name)" -ForegroundColor Yellow
        Write-Host "  Provisioning State: $($bastionData.provisioningState)" -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Creating Azure Bastion Host..." -ForegroundColor Cyan

    # Build command parameters
    $createParams = @(
        'network', 'bastion', 'create',
        '--name', $BastionName,
        '--public-ip-address', $PublicIpAddress,
        '--resource-group', $ResourceGroup,
        '--vnet-name', $VnetName,
        '--location', $Location,
        '--output', 'json'
    )

    # Add optional parameters
    if ($DisableCopyPaste) {
        $createParams += '--disable-copy-paste', 'true'
        Write-Host "  Will disable copy-paste functionality" -ForegroundColor Green
    }

    if ($EnableIpConnect) {
        $createParams += '--enable-ip-connect', 'true'
        Write-Host "  Will enable IP connect" -ForegroundColor Green
    }

    if ($EnableTunneling) {
        $createParams += '--enable-tunneling', 'true'
        Write-Host "  Will enable tunneling" -ForegroundColor Green
    }

    if ($FileCopy) {
        $createParams += '--file-copy', 'true'
        Write-Host "  Will enable file copy" -ForegroundColor Green
    }

    if ($Kerberos) {
        $createParams += '--kerberos', 'true'
        Write-Host "  Will enable Kerberos authentication" -ForegroundColor Green
    }

    if ($NoWait) {
        $createParams += '--no-wait'
        Write-Host "  Will not wait for operation completion" -ForegroundColor Green
    }

    if ($ScaleUnits) {
        $createParams += '--scale-units', $ScaleUnits
        Write-Host "  Will set scale units to: $ScaleUnits" -ForegroundColor Green
    }

    if ($SessionRecording) {
        $createParams += '--session-recording', 'true'
        Write-Host "  Will enable session recording" -ForegroundColor Green
    }

    if ($ShareableLink) {
        $createParams += '--shareable-link', 'true'
        Write-Host "  Will enable shareable link" -ForegroundColor Green
    }

    if ($Sku) {
        $createParams += '--sku', $Sku
        Write-Host "  Will use SKU: $Sku" -ForegroundColor Green
    }

    if ($Tags) {
        $createParams += '--tags', $Tags
        Write-Host "  Will apply tags: $Tags" -ForegroundColor Green
    }

    if ($Zones) {
        $createParams += '--zones', $Zones
        Write-Host "  Will use availability zones: $Zones" -ForegroundColor Green
    }

    if ($NoWait) {
        Write-Host "Starting Bastion Host creation (not waiting for completion)..." -ForegroundColor Yellow
        & az @createParams
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI command failed with exit code: $LASTEXITCODE"
        }
        Write-Host "✓ Bastion Host creation started successfully!" -ForegroundColor Green
        Write-Host "Use 'az network bastion show --name $BastionName --resource-group $ResourceGroup' to check status" -ForegroundColor Cyan
    } else {
        Write-Host "Creating Bastion Host (this may take several minutes)..." -ForegroundColor Yellow
        $result = & az @createParams
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI command failed with exit code: $LASTEXITCODE"
        }

        $bastionHost = $result | ConvertFrom-Json

        Write-Host "✓ Azure Bastion Host created successfully!" -ForegroundColor Green
        Write-Host "Bastion Host Details:" -ForegroundColor Cyan
        Write-Host "  Name: $($bastionHost.name)" -ForegroundColor White
        Write-Host "  Resource Group: $($bastionHost.resourceGroup)" -ForegroundColor White
        Write-Host "  Location: $($bastionHost.location)" -ForegroundColor White
        Write-Host "  SKU: $($bastionHost.sku.name)" -ForegroundColor White
        Write-Host "  Provisioning State: $($bastionHost.provisioningState)" -ForegroundColor White
        Write-Host "  DNS Name: $($bastionHost.dnsName)" -ForegroundColor White
        Write-Host "  ID: $($bastionHost.id)" -ForegroundColor White

        return $bastionHost
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
