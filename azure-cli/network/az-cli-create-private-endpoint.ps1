<#
.SYNOPSIS
    Create a private endpoint for an Azure PaaS service using the Azure CLI.

.DESCRIPTION
    This script creates a private endpoint that enables private network access to an Azure PaaS
    service (e.g. Storage, Key Vault, SQL) within a virtual network, using the Azure CLI.
    The script uses the following Azure CLI command:
    az network private-endpoint create --resource-group $ResourceGroupName --name $EndpointName

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group where the private endpoint will be created.

.PARAMETER EndpointName
    Defines the name of the private endpoint resource.

.PARAMETER VnetName
    Defines the name of the virtual network in which to create the private endpoint.

.PARAMETER SubnetName
    Defines the name of the subnet within the VNet for the private endpoint.

.PARAMETER ServiceResourceId
    Defines the full resource ID of the target Azure PaaS service.

.PARAMETER GroupId
    Defines the private link group ID (sub-resource) of the target service.
    Examples: blob, vault, sqlServer, sites.

.PARAMETER Location
    Defines the Azure region for the private endpoint. Defaults to the VNet's location if omitted.

.PARAMETER ConnectionName
    Defines the name of the private link service connection. Defaults to EndpointName + "-connection".

.EXAMPLE
    .\az-cli-create-private-endpoint.ps1 -ResourceGroupName "rg-network" -EndpointName "pe-storage" -VnetName "prod-vnet" -SubnetName "private-endpoints" -ServiceResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-storage/providers/Microsoft.Storage/storageAccounts/mystorageacct" -GroupId "blob"

.EXAMPLE
    .\az-cli-create-private-endpoint.ps1 -ResourceGroupName "rg-network" -EndpointName "pe-keyvault" -VnetName "prod-vnet" -SubnetName "private-endpoints" -ServiceResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-security/providers/Microsoft.KeyVault/vaults/mykeyvault" -GroupId "vault" -ConnectionName "pe-keyvault-connection" -Location "eastus"

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
    https://learn.microsoft.com/en-us/cli/azure/network/private-endpoint

.COMPONENT
    Azure CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group where the private endpoint will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the private endpoint resource")]
    [ValidateNotNullOrEmpty()]
    [string]$EndpointName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the virtual network for the private endpoint")]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the subnet within the VNet for the private endpoint")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory = $true, HelpMessage = "The full resource ID of the target Azure PaaS service")]
    [ValidateNotNullOrEmpty()]
    [string]$ServiceResourceId,

    [Parameter(Mandatory = $true, HelpMessage = "The private link group ID (sub-resource) of the target service (e.g. blob, vault, sqlServer)")]
    [ValidateNotNullOrEmpty()]
    [string]$GroupId,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure region for the private endpoint (defaults to the VNet's location)")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the private link service connection (defaults to EndpointName + '-connection')")]
    [ValidateNotNullOrEmpty()]
    [string]$ConnectionName
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating private endpoint '$EndpointName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Default connection name
    if (-not $ConnectionName) {
        $ConnectionName = "$EndpointName-connection"
        Write-Host "ℹ️  ConnectionName not specified. Using: $ConnectionName" -ForegroundColor Yellow
    }

    # Resolve location from VNet if not specified
    if (-not $Location) {
        Write-Host "🔍 Resolving location from VNet '$VnetName'..." -ForegroundColor Cyan
        $vnetJson = az network vnet show `
            --resource-group $ResourceGroupName `
            --name $VnetName `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve VNet details for '$VnetName'. Specify -Location explicitly."
        }

        $vnet = $vnetJson | ConvertFrom-Json
        $Location = $vnet.location
        Write-Host "ℹ️  Using VNet location: $Location" -ForegroundColor Yellow
    }

    # Disable private endpoint network policies on the subnet (required for private endpoints)
    Write-Host "🔧 Disabling private endpoint network policies on subnet '$SubnetName'..." -ForegroundColor Cyan
    az network vnet subnet update `
        --resource-group $ResourceGroupName `
        --vnet-name $VnetName `
        --name $SubnetName `
        --disable-private-endpoint-network-policies true | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to update subnet network policies for '$SubnetName'."
    }

    # Create the private endpoint
    Write-Host "🔧 Creating private endpoint '$EndpointName'..." -ForegroundColor Cyan
    $endpointJson = az network private-endpoint create `
        --resource-group $ResourceGroupName `
        --name $EndpointName `
        --location $Location `
        --vnet-name $VnetName `
        --subnet $SubnetName `
        --private-connection-resource-id $ServiceResourceId `
        --group-id $GroupId `
        --connection-name $ConnectionName `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI private-endpoint create command failed with exit code $LASTEXITCODE"
    }

    $endpoint = $endpointJson | ConvertFrom-Json

    Write-Host "`n✅ Private endpoint '$EndpointName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   EndpointName:    $($endpoint.name)" -ForegroundColor White
    Write-Host "   Resource Group:  $($endpoint.resourceGroup)" -ForegroundColor White
    Write-Host "   Location:        $($endpoint.location)" -ForegroundColor White
    Write-Host "   VNet:            $VnetName" -ForegroundColor White
    Write-Host "   Subnet:          $SubnetName" -ForegroundColor White
    Write-Host "   GroupId:         $GroupId" -ForegroundColor White
    Write-Host "   ConnectionName:  $ConnectionName" -ForegroundColor White
    Write-Host "   ProvisioningState: $($endpoint.provisioningState)" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Configure a Private DNS Zone to resolve the service's private IP." -ForegroundColor White
    Write-Host "   - Run: az network private-dns zone create to create the DNS zone." -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
