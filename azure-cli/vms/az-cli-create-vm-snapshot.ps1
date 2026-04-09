<#
.SYNOPSIS
    Create a snapshot of an Azure VM's OS disk using the Azure CLI.

.DESCRIPTION
    This script creates a snapshot of an Azure Virtual Machine's OS disk using the Azure CLI.
    It first retrieves the VM's OS disk ID using az vm show, then creates the snapshot
    using az snapshot create.
    The script uses the following Azure CLI commands:
    az vm show --resource-group $ResourceGroupName --name $VmName
    az snapshot create --resource-group $ResourceGroupName --name $SnapshotName --source $DiskId

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the VM.

.PARAMETER VmName
    Defines the name of the Azure Virtual Machine whose OS disk will be snapshotted.

.PARAMETER SnapshotName
    Defines the name of the snapshot to create.

.PARAMETER Location
    Defines the Azure region where the snapshot will be created.
    Defaults to the VM's location if not specified.

.PARAMETER Sku
    Defines the SKU (storage type) for the snapshot.
    Valid values: Standard_LRS, Premium_LRS, Standard_ZRS. Default: Standard_LRS.

.EXAMPLE
    .\az-cli-create-vm-snapshot.ps1 -ResourceGroupName "rg-vms" -VmName "vm-web-prod-01" -SnapshotName "snap-vm-web-prod-01-20260408"

.EXAMPLE
    .\az-cli-create-vm-snapshot.ps1 -ResourceGroupName "rg-vms" -VmName "vm-web-prod-01" -SnapshotName "snap-vm-web-prod-01" -Sku "Premium_LRS" -Location "eastus"

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
    https://learn.microsoft.com/en-us/cli/azure/snapshot

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the VM")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Machine whose OS disk will be snapshotted")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the snapshot to create")]
    [ValidateNotNullOrEmpty()]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false, HelpMessage = "The Azure region for the snapshot (defaults to the VM's location)")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "The storage SKU for the snapshot: Standard_LRS, Premium_LRS, or Standard_ZRS")]
    [ValidateSet('Standard_LRS', 'Premium_LRS', 'Standard_ZRS')]
    [string]$Sku = 'Standard_LRS'
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Creating snapshot of VM '$VmName' OS disk in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Get VM details to retrieve the OS disk ID and location
    Write-Host "🔍 Retrieving VM details for '$VmName'..." -ForegroundColor Cyan
    $vmJson = az vm show `
        --resource-group $ResourceGroupName `
        --name $VmName `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve VM details. Verify the VM name and resource group are correct."
    }

    $vm = $vmJson | ConvertFrom-Json
    $diskId = $vm.storageProfile.osDisk.managedDisk.id

    if (-not $diskId) {
        throw "Could not retrieve the OS disk ID for VM '$VmName'. Ensure the VM uses managed disks."
    }

    Write-Host "✅ Retrieved OS disk ID: $diskId" -ForegroundColor Green

    # Use the VM's location if none specified
    if (-not $Location) {
        $Location = $vm.location
        Write-Host "ℹ️  Using VM location: $Location" -ForegroundColor Yellow
    }

    # Create the snapshot
    Write-Host "🔧 Creating snapshot '$SnapshotName' with SKU '$Sku'..." -ForegroundColor Cyan
    $snapshotJson = az snapshot create `
        --resource-group $ResourceGroupName `
        --name $SnapshotName `
        --source $diskId `
        --location $Location `
        --sku $Sku `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI snapshot create command failed with exit code $LASTEXITCODE"
    }

    $snapshot = $snapshotJson | ConvertFrom-Json

    Write-Host "`n✅ Snapshot '$SnapshotName' created successfully." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   SnapshotId:   $($snapshot.id)" -ForegroundColor White
    Write-Host "   SnapshotName: $($snapshot.name)" -ForegroundColor White
    Write-Host "   DiskSizeGb:   $($snapshot.diskSizeGb)" -ForegroundColor White
    Write-Host "   Location:     $($snapshot.location)" -ForegroundColor White
    Write-Host "   Sku:          $($snapshot.sku.name)" -ForegroundColor White
    Write-Host "   ProvisioningState: $($snapshot.provisioningState)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
