<#
.SYNOPSIS
    Enable Azure DDoS Network Protection on a VNet using the Azure CLI.

.DESCRIPTION
    This script enables Azure DDoS Network Protection on a Virtual Network using the Azure CLI.
    Optionally, it creates a new DDoS protection plan first and links it to the VNet.
    The script uses the following Azure CLI commands:
    az network ddos-protection create (when DdosPlanName is provided)
    az network vnet update --ddos-protection true --ddos-protection-plan $PlanId

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the VNet.

.PARAMETER VnetName
    Defines the name of the Virtual Network to enable DDoS protection on.

.PARAMETER DdosPlanName
    Defines the name of the DDoS protection plan to create or use.
    If provided, a new plan is created (or an existing one with this name is used).

.PARAMETER DdosPlanResourceGroup
    Defines the Resource Group for the DDoS protection plan.
    Defaults to ResourceGroupName if not specified.

.PARAMETER Location
    Defines the Azure region for the DDoS protection plan (required when creating a new plan).

.EXAMPLE
    .\az-cli-enable-ddos-protection.ps1 -ResourceGroupName "rg-network" -VnetName "prod-vnet" -DdosPlanName "ddos-plan-prod" -Location "eastus"

.EXAMPLE
    .\az-cli-enable-ddos-protection.ps1 -ResourceGroupName "rg-network" -VnetName "prod-vnet" -DdosPlanName "shared-ddos-plan" -DdosPlanResourceGroup "rg-security" -Location "eastus"

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
    https://learn.microsoft.com/en-us/cli/azure/network/ddos-protection

.COMPONENT
    Azure CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the VNet")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Virtual Network to enable DDoS protection on")]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the DDoS protection plan to create or use")]
    [ValidateNotNullOrEmpty()]
    [string]$DdosPlanName,

    [Parameter(Mandatory = $false, HelpMessage = "The Resource Group for the DDoS protection plan (defaults to ResourceGroupName)")]
    [ValidateNotNullOrEmpty()]
    [string]$DdosPlanResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure region for the DDoS protection plan (required when creating a new plan)")]
    [ValidateNotNullOrEmpty()]
    [string]$Location
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Enabling DDoS protection on VNet '$VnetName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    $ddosPlanId = $null

    if ($DdosPlanName) {
        # Default plan resource group
        if (-not $DdosPlanResourceGroup) {
            $DdosPlanResourceGroup = $ResourceGroupName
            Write-Host "ℹ️  DdosPlanResourceGroup not specified. Using: $DdosPlanResourceGroup" -ForegroundColor Yellow
        }

        # Check if the plan already exists
        Write-Host "🔍 Checking if DDoS protection plan '$DdosPlanName' already exists..." -ForegroundColor Cyan
        $existingPlanJson = az network ddos-protection show `
            --name $DdosPlanName `
            --resource-group $DdosPlanResourceGroup `
            --output json 2>$null

        if ($LASTEXITCODE -eq 0 -and $existingPlanJson) {
            $existingPlan = $existingPlanJson | ConvertFrom-Json
            $ddosPlanId = $existingPlan.id
            Write-Host "ℹ️  Existing DDoS protection plan found. ID: $ddosPlanId" -ForegroundColor Yellow
        }
        else {
            # Create a new DDoS protection plan
            if (-not $Location) {
                throw "Location must be specified when creating a new DDoS protection plan."
            }

            Write-Host "🔧 Creating DDoS protection plan '$DdosPlanName'..." -ForegroundColor Cyan
            $planJson = az network ddos-protection create `
                --name $DdosPlanName `
                --resource-group $DdosPlanResourceGroup `
                --location $Location `
                --output json

            if ($LASTEXITCODE -ne 0) {
                throw "Failed to create DDoS protection plan '$DdosPlanName'."
            }

            $plan = $planJson | ConvertFrom-Json
            $ddosPlanId = $plan.id
            Write-Host "✅ DDoS protection plan '$DdosPlanName' created. ID: $ddosPlanId" -ForegroundColor Green
        }

        # Enable DDoS protection on the VNet with the plan
        Write-Host "🔧 Enabling DDoS protection on VNet '$VnetName' with plan '$DdosPlanName'..." -ForegroundColor Cyan
        az network vnet update `
            --resource-group $ResourceGroupName `
            --name $VnetName `
            --ddos-protection true `
            --ddos-protection-plan $ddosPlanId `
            --output none

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enable DDoS protection on VNet '$VnetName'."
        }
    }
    else {
        # Enable basic DDoS protection without a plan
        Write-Host "🔧 Enabling DDoS protection on VNet '$VnetName'..." -ForegroundColor Cyan
        Write-Host "⚠️  No DdosPlanName specified. Enabling DDoS protection without a dedicated plan." -ForegroundColor Yellow
        az network vnet update `
            --resource-group $ResourceGroupName `
            --name $VnetName `
            --ddos-protection true `
            --output none

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enable DDoS protection on VNet '$VnetName'."
        }
    }

    # Retrieve updated VNet details
    $vnetJson = az network vnet show `
        --resource-group $ResourceGroupName `
        --name $VnetName `
        --output json

    $vnet = $vnetJson | ConvertFrom-Json

    Write-Host "`n✅ DDoS protection enabled on VNet '$VnetName' successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   VNetName:      $($vnet.name)" -ForegroundColor White
    Write-Host "   Resource Group: $($vnet.resourceGroup)" -ForegroundColor White
    Write-Host "   Location:      $($vnet.location)" -ForegroundColor White
    Write-Host "   DDoS Enabled:  $($vnet.enableDdosProtection)" -ForegroundColor White

    if ($DdosPlanName) {
        Write-Host "   DDoS Plan:     $DdosPlanName" -ForegroundColor White
        Write-Host "   Plan ID:       $ddosPlanId" -ForegroundColor White
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
