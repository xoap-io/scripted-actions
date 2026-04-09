<#
.SYNOPSIS
    Deploy a Virtual Network with up to three subnets using an inline Bicep template.

.DESCRIPTION
    This script writes an inline Bicep template to a temporary file and deploys
    an Azure Virtual Network with configurable subnets via
    `az deployment group create --template-file`. Up to three subnets can be
    defined by supplying the corresponding name and prefix parameters. Optionally,
    DDoS Protection Standard can be enabled. The temporary .bicep file is removed
    in the finally block regardless of success or failure.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group to deploy into.

.PARAMETER VnetName
    The name of the virtual network to create.

.PARAMETER Location
    The Azure region where resources will be deployed (e.g. westeurope).

.PARAMETER AddressPrefix
    The address space for the VNet in CIDR notation (e.g. 10.0.0.0/16).

.PARAMETER Subnet1Name
    The name of the first subnet. Defaults to "default".

.PARAMETER Subnet1Prefix
    The address prefix of the first subnet in CIDR notation. Defaults to 10.0.0.0/24.

.PARAMETER Subnet2Name
    The name of an optional second subnet.

.PARAMETER Subnet2Prefix
    The address prefix of the optional second subnet in CIDR notation.

.PARAMETER Subnet3Name
    The name of an optional third subnet.

.PARAMETER Subnet3Prefix
    The address prefix of the optional third subnet in CIDR notation.

.PARAMETER EnableDdosProtection
    When specified, DDoS Protection Standard is enabled on the VNet.

.PARAMETER DeploymentName
    The ARM deployment name. Defaults to "<VnetName>-deployment-<timestamp>".

.EXAMPLE
    .\bicep-deploy-vnet.ps1 `
        -ResourceGroupName "rg-network-prod" `
        -VnetName "vnet-prod-eastus" `
        -Location "eastus" `
        -AddressPrefix "10.10.0.0/16" `
        -Subnet1Name "snet-web" `
        -Subnet1Prefix "10.10.1.0/24" `
        -Subnet2Name "snet-app" `
        -Subnet2Prefix "10.10.2.0/24" `
        -Subnet3Name "snet-db" `
        -Subnet3Prefix "10.10.3.0/24"

.EXAMPLE
    .\bicep-deploy-vnet.ps1 `
        -ResourceGroupName "rg-dev" `
        -VnetName "vnet-dev" `
        -Location "northeurope" `
        -AddressPrefix "192.168.0.0/20" `
        -EnableDdosProtection

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI with Bicep extension (run `az bicep install` to install)

.LINK
    https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/

.COMPONENT
    Azure Bicep

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group to deploy into")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the virtual network to create")]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where resources will be deployed (e.g. westeurope)")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "VNet address space in CIDR notation (e.g. 10.0.0.0/16)")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$AddressPrefix,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the first subnet (default: default)")]
    [ValidateNotNullOrEmpty()]
    [string]$Subnet1Name = 'default',

    [Parameter(Mandatory = $false, HelpMessage = "Address prefix of the first subnet in CIDR notation (default: 10.0.0.0/24)")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Subnet1Prefix = '10.0.0.0/24',

    [Parameter(Mandatory = $false, HelpMessage = "Name of the optional second subnet")]
    [ValidateNotNullOrEmpty()]
    [string]$Subnet2Name,

    [Parameter(Mandatory = $false, HelpMessage = "Address prefix of the optional second subnet in CIDR notation")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Subnet2Prefix,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the optional third subnet")]
    [ValidateNotNullOrEmpty()]
    [string]$Subnet3Name,

    [Parameter(Mandatory = $false, HelpMessage = "Address prefix of the optional third subnet in CIDR notation")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Subnet3Prefix,

    [Parameter(Mandatory = $false, HelpMessage = "When specified, DDoS Protection Standard is enabled on the VNet")]
    [switch]$EnableDdosProtection,

    [Parameter(Mandatory = $false, HelpMessage = "The ARM deployment name (default: auto-generated with timestamp)")]
    [ValidateNotNullOrEmpty()]
    [string]$DeploymentName
)

$ErrorActionPreference = 'Stop'

if (-not $DeploymentName) {
    $DeploymentName = "$VnetName-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"
}

$tempBicepFile = $null

try {
    Write-Host "🚀 Starting VNet deployment via Bicep" -ForegroundColor Green
    Write-Host "   VNet Name      : $VnetName" -ForegroundColor Cyan
    Write-Host "   Resource Group : $ResourceGroupName" -ForegroundColor Cyan
    Write-Host "   Location       : $Location" -ForegroundColor Cyan
    Write-Host "   Address Prefix : $AddressPrefix" -ForegroundColor Cyan

    # Validate prerequisites
    Write-Host "`n🔍 Validating prerequisites..." -ForegroundColor Cyan

    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI (az) is not installed or not in PATH. Install from https://aka.ms/installazurecliwindows"
    }

    $bicepVersion = az bicep version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠️  Bicep not found — running 'az bicep install'..." -ForegroundColor Yellow
        az bicep install
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install Bicep. Run 'az bicep install' manually."
        }
    }
    else {
        Write-Host "✅ Bicep version: $bicepVersion" -ForegroundColor Green
    }

    # Build the subnets array for the Bicep template
    Write-Host "`n🔧 Building subnet configuration..." -ForegroundColor Cyan

    $subnetEntries = @()
    $subnetEntries += "      { name: '$Subnet1Name', properties: { addressPrefix: '$Subnet1Prefix' } }"

    if ($Subnet2Name -and $Subnet2Prefix) {
        Write-Host "   Subnet 2: $Subnet2Name ($Subnet2Prefix)" -ForegroundColor Cyan
        $subnetEntries += "      { name: '$Subnet2Name', properties: { addressPrefix: '$Subnet2Prefix' } }"
    }
    elseif ($Subnet2Name -or $Subnet2Prefix) {
        Write-Host "⚠️  Subnet2Name and Subnet2Prefix must both be provided — skipping Subnet 2" -ForegroundColor Yellow
    }

    if ($Subnet3Name -and $Subnet3Prefix) {
        Write-Host "   Subnet 3: $Subnet3Name ($Subnet3Prefix)" -ForegroundColor Cyan
        $subnetEntries += "      { name: '$Subnet3Name', properties: { addressPrefix: '$Subnet3Prefix' } }"
    }
    elseif ($Subnet3Name -or $Subnet3Prefix) {
        Write-Host "⚠️  Subnet3Name and Subnet3Prefix must both be provided — skipping Subnet 3" -ForegroundColor Yellow
    }

    $subnetsBlock = $subnetEntries -join "`n"
    $ddosBool = if ($EnableDdosProtection) { 'true' } else { 'false' }

    # Write inline Bicep template to a temp file
    Write-Host "`n🔧 Writing Bicep template to temp file..." -ForegroundColor Cyan

    $bicepTemplate = @"
param vnetName string
param location string
param addressPrefix string
param enableDdosProtection bool

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    enableDdosProtection: enableDdosProtection
    subnets: [
$subnetsBlock
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetCount int = length(vnet.properties.subnets)
"@

    $tempBicepFile = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.bicep'
    Set-Content -Path $tempBicepFile -Value $bicepTemplate -Encoding UTF8
    Write-Host "✅ Bicep template written to: $tempBicepFile" -ForegroundColor Green

    # Deploy via Azure CLI
    Write-Host "`n🔧 Deploying Bicep template..." -ForegroundColor Cyan

    $deployArgs = @(
        'deployment', 'group', 'create',
        '--resource-group', $ResourceGroupName,
        '--name', $DeploymentName,
        '--template-file', $tempBicepFile,
        '--parameters',
        "vnetName=$VnetName",
        "location=$Location",
        "addressPrefix=$AddressPrefix",
        "enableDdosProtection=$ddosBool",
        '--output', 'json'
    )

    $result = az @deployArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed: $result"
    }

    $deploymentOutput = $result | ConvertFrom-Json

    Write-Host "`n✅ Deployment succeeded!" -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Deployment Name  : $DeploymentName" -ForegroundColor White
    Write-Host "   Provisioning     : $($deploymentOutput.properties.provisioningState)" -ForegroundColor White

    $outputs = $deploymentOutput.properties.outputs
    if ($outputs.vnetId) {
        Write-Host "   VNet ID          : $($outputs.vnetId.value)" -ForegroundColor White
    }
    if ($outputs.subnetCount) {
        Write-Host "   Subnets created  : $($outputs.subnetCount.value)" -ForegroundColor White
    }
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($tempBicepFile -and (Test-Path $tempBicepFile)) {
        Remove-Item -Path $tempBicepFile -Force
        Write-Host "`n🔧 Cleaned up temp Bicep file" -ForegroundColor Cyan
    }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
