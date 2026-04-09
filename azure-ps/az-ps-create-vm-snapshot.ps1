<#
.SYNOPSIS
    Create a snapshot of an Azure VM OS disk using the Az PowerShell module.

.DESCRIPTION
    This script creates a snapshot of the OS disk attached to an Azure virtual machine
    using New-AzSnapshot. It first retrieves the VM with Get-AzVM to identify the managed
    OS disk, then builds a snapshot configuration and creates the snapshot in the same
    resource group as the VM.
    The underlying commands used are:
    Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    New-AzSnapshotConfig -SourceUri $disk.Id -Location $vm.Location -CreateOption Copy -SkuName $Sku
    New-AzSnapshot -ResourceGroupName $ResourceGroupName -SnapshotName $SnapshotName -Snapshot $snapshotConfig

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group containing the VM and where the snapshot will be created.

.PARAMETER VmName
    The name of the Azure virtual machine whose OS disk will be snapshotted.

.PARAMETER SnapshotName
    The name to assign to the new snapshot.

.PARAMETER Sku
    The storage SKU for the snapshot. Valid values: Standard_LRS, Premium_LRS.
    Default: Standard_LRS

.EXAMPLE
    .\az-ps-create-vm-snapshot.ps1 -ResourceGroupName "MyRG" -VmName "MyVM" -SnapshotName "MyVM-OS-Snapshot-20260408"

    Create a standard LRS snapshot of the VM OS disk.

.EXAMPLE
    .\az-ps-create-vm-snapshot.ps1 -ResourceGroupName "ProdRG" -VmName "ProdVM" -SnapshotName "ProdVM-PreUpdate" -Sku Premium_LRS

    Create a premium snapshot before applying updates.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Compute PowerShell module

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azsnapshot

.COMPONENT
    Azure PowerShell Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the VM.")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure virtual machine whose OS disk will be snapshotted.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $true, HelpMessage = "The name to assign to the new snapshot.")]
    [ValidateNotNullOrEmpty()]
    [string]$SnapshotName,

    [Parameter(Mandatory = $false, HelpMessage = "The storage SKU for the snapshot. Valid values: Standard_LRS, Premium_LRS.")]
    [ValidateSet('Standard_LRS', 'Premium_LRS')]
    [string]$Sku = 'Standard_LRS'
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting Azure VM snapshot creation..." -ForegroundColor Green

    # Import module
    Write-Host "🔍 Loading Az.Compute module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name Az.Compute -ListAvailable)) {
        throw "Az.Compute module is not installed. Install it with: Install-Module Az.Compute"
    }
    Import-Module Az.Compute -ErrorAction Stop

    # Get the VM
    Write-Host "🔍 Retrieving VM '$VmName' in resource group '$ResourceGroupName'..." -ForegroundColor Cyan
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -ErrorAction Stop

    if (-not $vm) {
        throw "VM '$VmName' not found in resource group '$ResourceGroupName'."
    }

    $osDiskId = $vm.StorageProfile.OsDisk.ManagedDisk.Id
    if (-not $osDiskId) {
        throw "VM '$VmName' does not have a managed OS disk. Unmanaged disks are not supported."
    }

    Write-Host "ℹ️  OS Disk ID: $osDiskId" -ForegroundColor Yellow
    Write-Host "ℹ️  Location: $($vm.Location)" -ForegroundColor Yellow
    Write-Host "ℹ️  Snapshot SKU: $Sku" -ForegroundColor Yellow

    # Create snapshot config
    Write-Host "🔧 Creating snapshot configuration..." -ForegroundColor Cyan
    $snapshotConfig = New-AzSnapshotConfig `
        -SourceUri $osDiskId `
        -Location $vm.Location `
        -CreateOption Copy `
        -SkuName $Sku

    # Create snapshot
    Write-Host "🔧 Creating snapshot '$SnapshotName'..." -ForegroundColor Cyan
    $snapshot = New-AzSnapshot `
        -ResourceGroupName $ResourceGroupName `
        -SnapshotName $SnapshotName `
        -Snapshot $snapshotConfig

    Write-Host "✅ Snapshot '$SnapshotName' created successfully." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  Snapshot Name : $($snapshot.Name)" -ForegroundColor White
    Write-Host "  Resource Group: $($snapshot.ResourceGroupName)" -ForegroundColor White
    Write-Host "  Location      : $($snapshot.Location)" -ForegroundColor White
    Write-Host "  Disk Size (GB): $($snapshot.DiskSizeGB)" -ForegroundColor White
    Write-Host "  SKU           : $($snapshot.Sku.Name)" -ForegroundColor White
    Write-Host "  Provisioning  : $($snapshot.ProvisioningState)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
