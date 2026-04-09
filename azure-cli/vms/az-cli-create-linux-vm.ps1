<#
.SYNOPSIS
    Create a Linux Azure Virtual Machine using the Azure CLI.

.DESCRIPTION
    This script creates a Linux Azure Virtual Machine using the Azure CLI.
    It supports SSH key authentication, optional VNet/subnet placement, NSG
    assignment, and public IP allocation.
    The script uses the following Azure CLI command:
    az vm create --resource-group $ResourceGroupName --name $VmName --image $Image

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group where the VM will be created.

.PARAMETER VmName
    Defines the name of the Azure Virtual Machine.

.PARAMETER Location
    Defines the Azure region where the VM will be created.

.PARAMETER Image
    Defines the OS image for the VM (e.g. Ubuntu2204, RedHat8_6, Debian11).

.PARAMETER VmSize
    Defines the size of the Azure Virtual Machine. Default: Standard_DS1_v2.

.PARAMETER AdminUsername
    Defines the administrator username for the Linux VM.

.PARAMETER SshPublicKeyPath
    Defines the path to an existing SSH public key (.pub) file for authentication.
    If omitted, Azure generates a new SSH key pair.

.PARAMETER VnetName
    Defines the name of an existing virtual network to place the VM in.

.PARAMETER SubnetName
    Defines the name of the subnet within the VNet (required if VnetName is specified).

.PARAMETER PublicIp
    If specified, allocates a public IP address for the VM.

.PARAMETER NsgName
    Defines the name of an existing Network Security Group to associate with the VM.

.EXAMPLE
    .\az-cli-create-linux-vm.ps1 -ResourceGroupName "rg-vms" -VmName "vm-linux-prod-01" -Location "eastus" -Image "Ubuntu2204" -AdminUsername "azureuser"

.EXAMPLE
    .\az-cli-create-linux-vm.ps1 -ResourceGroupName "rg-vms" -VmName "vm-linux-prod-01" -Location "eastus" -Image "Ubuntu2204" -VmSize "Standard_D2s_v3" -AdminUsername "azureuser" -SshPublicKeyPath "~/.ssh/id_rsa.pub" -VnetName "prod-vnet" -SubnetName "default" -PublicIp -NsgName "web-nsg"

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
    https://learn.microsoft.com/en-us/cli/azure/vm

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group where the VM will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Machine")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region where the VM will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $true, HelpMessage = "The OS image for the VM (e.g. Ubuntu2204, RedHat8_6, Debian11)")]
    [ValidateNotNullOrEmpty()]
    [string]$Image,

    [Parameter(Mandatory = $false, HelpMessage = "The size of the Azure Virtual Machine")]
    [ValidateNotNullOrEmpty()]
    [string]$VmSize = 'Standard_DS1_v2',

    [Parameter(Mandatory = $true, HelpMessage = "The administrator username for the Linux VM")]
    [ValidateNotNullOrEmpty()]
    [string]$AdminUsername,

    [Parameter(Mandatory = $false, HelpMessage = "Path to an existing SSH public key (.pub) file. If omitted, Azure generates a new key pair.")]
    [ValidateNotNullOrEmpty()]
    [string]$SshPublicKeyPath,

    [Parameter(Mandatory = $false, HelpMessage = "The name of an existing virtual network to place the VM in")]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the subnet within the VNet (required if VnetName is specified)")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory = $false, HelpMessage = "Allocate a public IP address for the VM")]
    [switch]$PublicIp,

    [Parameter(Mandatory = $false, HelpMessage = "The name of an existing Network Security Group to associate with the VM NIC")]
    [ValidateNotNullOrEmpty()]
    [string]$NsgName
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating Linux VM '$VmName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Validate that SubnetName is provided when VnetName is specified
    if ($VnetName -and -not $SubnetName) {
        throw "SubnetName must be specified when VnetName is provided."
    }

    # Validate SSH public key file if provided
    if ($SshPublicKeyPath) {
        $resolvedKeyPath = [System.IO.Path]::GetFullPath($SshPublicKeyPath.Replace('~', $HOME))
        if (-not (Test-Path $resolvedKeyPath)) {
            throw "SSH public key file not found at path: $SshPublicKeyPath"
        }
        Write-Host "🔍 Using SSH public key from: $SshPublicKeyPath" -ForegroundColor Cyan
    }
    else {
        Write-Host "ℹ️  No SSH key path provided. Azure will generate a new SSH key pair." -ForegroundColor Yellow
    }

    # Build the az vm create command arguments
    $createArgs = @(
        'vm', 'create',
        '--resource-group', $ResourceGroupName,
        '--name', $VmName,
        '--location', $Location,
        '--image', $Image,
        '--size', $VmSize,
        '--admin-username', $AdminUsername,
        '--output', 'json'
    )

    if ($SshPublicKeyPath) {
        $createArgs += '--ssh-key-values'
        $createArgs += $SshPublicKeyPath
    }
    else {
        $createArgs += '--generate-ssh-keys'
    }

    if ($PublicIp) {
        $createArgs += '--public-ip-sku'
        $createArgs += 'Standard'
    }
    else {
        $createArgs += '--public-ip-address'
        $createArgs += '""'
    }

    if ($VnetName) {
        $createArgs += '--vnet-name'
        $createArgs += $VnetName
        $createArgs += '--subnet'
        $createArgs += $SubnetName
    }

    if ($NsgName) {
        $createArgs += '--nsg'
        $createArgs += $NsgName
    }

    # Create the VM
    Write-Host "🔧 Running az vm create for '$VmName'..." -ForegroundColor Cyan
    $vmJson = az @createArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI vm create command failed with exit code $LASTEXITCODE"
    }

    $vm = $vmJson | ConvertFrom-Json

    Write-Host "`n✅ Linux VM '$VmName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   Resource ID: $($vm.id)" -ForegroundColor White
    Write-Host "   Location:    $($vm.location)" -ForegroundColor White

    if ($vm.publicIpAddress) {
        Write-Host "   Public IP:   $($vm.publicIpAddress)" -ForegroundColor White
    }

    if ($vm.fqdns) {
        Write-Host "   FQDN:        $($vm.fqdns)" -ForegroundColor White
    }

    if ($vm.publicIpAddress) {
        Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
        Write-Host "   Connect via SSH: ssh $AdminUsername@$($vm.publicIpAddress)" -ForegroundColor White
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
