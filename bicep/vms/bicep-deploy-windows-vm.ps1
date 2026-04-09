<#
.SYNOPSIS
    Deploy a Windows Server 2022 VM to Azure using an inline Bicep template.

.DESCRIPTION
    This script writes an inline Bicep template to a temporary file and deploys
    a Windows Server 2022 VM using `az deployment group create --template-file`.
    The deployment provisions a VNet, subnet, NIC, optional public IP, NSG with
    an RDP allow rule, and the VM itself. The temporary .bicep file is removed
    in the finally block regardless of success or failure.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group to deploy into.

.PARAMETER VmName
    The name of the virtual machine to create.

.PARAMETER Location
    The Azure region where resources will be deployed (e.g. eastus).

.PARAMETER AdminUsername
    The administrator username for the Windows VM.

.PARAMETER AdminPassword
    The administrator password for the Windows VM as a SecureString.

.PARAMETER VmSize
    The Azure VM size. Defaults to Standard_DS1_v2.

.PARAMETER VnetName
    The name of the virtual network. Defaults to "<VmName>-vnet".

.PARAMETER SubnetName
    The name of the subnet inside the VNet. Defaults to "default".

.PARAMETER AddPublicIp
    When specified, a public IP address is created and attached to the NIC.

.PARAMETER DeploymentName
    The name for the ARM deployment. Defaults to "<VmName>-deployment-<timestamp>".

.EXAMPLE
    .\bicep-deploy-windows-vm.ps1 `
        -ResourceGroupName "rg-prod-eastus" `
        -VmName "vm-web-01" `
        -Location "eastus" `
        -AdminUsername "azureadmin" `
        -AdminPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
        -AddPublicIp

.EXAMPLE
    .\bicep-deploy-windows-vm.ps1 `
        -ResourceGroupName "rg-dev" `
        -VmName "vm-dev-01" `
        -Location "westeurope" `
        -AdminUsername "localadmin" `
        -AdminPassword (ConvertTo-SecureString "MyS3cur3Pass!" -AsPlainText -Force) `
        -VmSize "Standard_B2s" `
        -VnetName "vnet-dev" `
        -SubnetName "snet-vms"

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the virtual machine to create")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where resources will be deployed (e.g. eastus)")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "The administrator username for the Windows VM")]
    [ValidateNotNullOrEmpty()]
    [string]$AdminUsername,

    [Parameter(Mandatory = $true, HelpMessage = "The administrator password for the Windows VM as a SecureString")]
    [ValidateNotNullOrEmpty()]
    [securestring]$AdminPassword,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure VM size (default: Standard_DS1_v2)")]
    [ValidateNotNullOrEmpty()]
    [string]$VmSize = 'Standard_DS1_v2',

    [Parameter(Mandatory = $false, HelpMessage = "The name of the virtual network (default: <VmName>-vnet)")]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory = $false, HelpMessage = "The subnet name inside the VNet (default: default)")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName = 'default',

    [Parameter(Mandatory = $false, HelpMessage = "When specified, a public IP address is created and attached")]
    [switch]$AddPublicIp,

    [Parameter(Mandatory = $false, HelpMessage = "The ARM deployment name (default: auto-generated with timestamp)")]
    [ValidateNotNullOrEmpty()]
    [string]$DeploymentName
)

$ErrorActionPreference = 'Stop'

# Apply defaults that depend on other parameters
if (-not $VnetName) { $VnetName = "$VmName-vnet" }
if (-not $DeploymentName) { $DeploymentName = "$VmName-deployment-$(Get-Date -Format 'yyyyMMddHHmmss')" }

# Convert SecureString to plain text for Bicep parameter passing
$AdminPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword)
)

$tempBicepFile = $null

try {
    Write-Host "🚀 Starting Windows VM deployment via Bicep" -ForegroundColor Green
    Write-Host "   VM Name        : $VmName" -ForegroundColor Cyan
    Write-Host "   Resource Group : $ResourceGroupName" -ForegroundColor Cyan
    Write-Host "   Location       : $Location" -ForegroundColor Cyan
    Write-Host "   VM Size        : $VmSize" -ForegroundColor Cyan
    Write-Host "   Public IP      : $($AddPublicIp.IsPresent)" -ForegroundColor Cyan

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

    # Write inline Bicep template to a temp file
    Write-Host "`n🔧 Writing Bicep template to temp file..." -ForegroundColor Cyan

    $addPublicIpBool = if ($AddPublicIp) { 'true' } else { 'false' }

    $bicepTemplate = @"
param vmName string
param location string
param adminUsername string
@secure()
param adminPassword string
param vmSize string
param vnetName string
param subnetName string
param addPublicIp bool

var nsgName = '\${vmName}-nsg'
var nicName = '\${vmName}-nic'
var publicIpName = '\${vmName}-pip'
var vnetAddressPrefix = '10.0.0.0/16'
var subnetAddressPrefix = '10.0.0.0/24'

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-rdp'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = if (addPublicIp) {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: addPublicIp ? {
            id: publicIp.id
          } : null
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output vmId string = vm.id
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
output publicIpAddress string = addPublicIp ? publicIp.properties.ipAddress : 'N/A'
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
        "vmName=$VmName",
        "location=$Location",
        "adminUsername=$AdminUsername",
        "adminPassword=$AdminPasswordPlain",
        "vmSize=$VmSize",
        "vnetName=$VnetName",
        "subnetName=$SubnetName",
        "addPublicIp=$addPublicIpBool",
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
    if ($outputs.privateIpAddress) {
        Write-Host "   Private IP       : $($outputs.privateIpAddress.value)" -ForegroundColor White
    }
    if ($outputs.publicIpAddress -and $outputs.publicIpAddress.value -ne 'N/A') {
        Write-Host "   Public IP        : $($outputs.publicIpAddress.value)" -ForegroundColor White
    }

    if ($AddPublicIp) {
        Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   Connect via RDP: mstsc /v:$($outputs.publicIpAddress.value)" -ForegroundColor White
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
