<#
.SYNOPSIS
    Create a data disk and attach it to an Azure Local (Azure Stack HCI) virtual machine.

.DESCRIPTION
    This script creates a new virtual hard disk on an Azure Local cluster and attaches it to
    an existing Arc-managed virtual machine as a data disk. Dynamic (thin-provisioned) disks
    are created by default; pass -Fixed for a fixed-size disk. After attaching, initialize
    and format the disk inside the guest OS.

    Uses Get-AzStackHCIVMVirtualMachine, New-AzStackHCIVMVirtualHardDisk and
    Add-AzStackHCIVMVirtualMachineDataDisk.

    This script can run anywhere with an Azure context; it does not need to run on a
    cluster node.

.PARAMETER VmName
    Name of the virtual machine the data disk is attached to.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER CustomLocationId
    Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).
    Defaults to the XOAP LocalBox custom location "jumpstart".

.PARAMETER Location
    Azure region of the Arc resources. Defaults to "westeurope".

.PARAMETER DiskName
    Name of the new data disk. Defaults to "<VmName>-data-<timestamp>".

.PARAMETER DiskSizeGB
    Size of the new data disk in GB.

.PARAMETER Fixed
    Create a fixed-size disk instead of a dynamically expanding one.

.PARAMETER StoragePathName
    Optional storage path object that hosts the disk. If omitted, the cluster places the
    disk automatically.

.EXAMPLE
    .\az-ps-add-azure-local-vm-data-disk.ps1 -VmName "avd-host-01" -DiskSizeGB 128

    Creates a 128 GB dynamic data disk and attaches it to the VM.

.EXAMPLE
    .\az-ps-add-azure-local-vm-data-disk.ps1 `
        -VmName "sql-01" `
        -DiskName "sql-01-data01" `
        -DiskSizeGB 512 `
        -Fixed `
        -StoragePathName "sp-images"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM)

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-arc-virtual-machines

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the virtual machine the data disk is attached to.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Custom Location resource ID that maps to your Azure Local cluster (Arc resource bridge).")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomLocationId = "/subscriptions/e5373ae1-c1cf-418e-8044-a2851af745b6/resourceGroups/AzureLocal/providers/Microsoft.ExtendedLocation/customLocations/jumpstart",

    [Parameter(Mandatory = $false, HelpMessage = "Azure region of the Arc resources.")]
    [ValidateNotNullOrEmpty()]
    [string]$Location = "westeurope",

    [Parameter(Mandatory = $false, HelpMessage = "Name of the new data disk. Defaults to '<VmName>-data-<timestamp>'.")]
    [string]$DiskName = "",

    [Parameter(Mandatory = $true, HelpMessage = "Size of the new data disk in GB.")]
    [ValidateRange(1, 65536)]
    [int]$DiskSizeGB,

    [Parameter(Mandatory = $false, HelpMessage = "Create a fixed-size disk instead of a dynamically expanding one.")]
    [switch]$Fixed,

    [Parameter(Mandatory = $false, HelpMessage = "Optional storage path object that hosts the disk.")]
    [string]$StoragePathName = ""
)

$ErrorActionPreference = 'Stop'

try {
    # 0) Preflight: module + Azure context
    if (-not (Get-Module -ListAvailable -Name Az.StackHCIVM)) {
        throw "The Az.StackHCIVM module is not installed. Run: Install-Module Az.StackHCIVM -Scope CurrentUser"
    }
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. Run Connect-AzAccount (or sign in with your service principal) first."
    }
    Write-Host "🔍 Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    if (-not $DiskName) {
        $DiskName = "$($VmName)-data-$(Get-Date -Format 'yyyyMMddHHmmss')"
    }

    # 1) Resolve the VM
    $vm = Get-AzStackHCIVMVirtualMachine -Name $VmName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $vm) {
        throw "VM '$VmName' not found in resource group '$ResourceGroupName'."
    }

    # 2) Ensure the disk name is not taken
    $existingDisk = Get-AzStackHCIVMVirtualHardDisk -ResourceGroupName $ResourceGroupName -Name $DiskName -ErrorAction SilentlyContinue
    if ($existingDisk) {
        throw "A virtual hard disk named '$DiskName' already exists in resource group '$ResourceGroupName'. Choose a different -DiskName."
    }

    # 3) Create the data disk
    $diskType = if ($Fixed) { "fixed" } else { "dynamic" }
    Write-Host "🔧 Creating $diskType data disk '$DiskName' ($DiskSizeGB GB)..." -ForegroundColor Cyan

    $diskParams = @{
        Name              = $DiskName
        ResourceGroupName = $ResourceGroupName
        CustomLocationId  = $CustomLocationId
        Location          = $Location
        SizeGb            = [int64]$DiskSizeGB
    }
    if (-not $Fixed)         { $diskParams['Dynamic'] = $true }
    if ($StoragePathName)    { $diskParams['StoragePathName'] = $StoragePathName }

    $disk = New-AzStackHCIVMVirtualHardDisk @diskParams
    Write-Host "✅ Data disk '$DiskName' created (provisioning state: $($disk.ProvisioningState))" -ForegroundColor Green

    # 4) Attach the disk to the VM
    Write-Host "🔧 Attaching data disk '$DiskName' to VM '$VmName'..." -ForegroundColor Cyan
    $null = Add-AzStackHCIVMVirtualMachineDataDisk -Name $VmName -ResourceGroupName $ResourceGroupName -DataDiskName $DiskName

    Write-Host "✅ Data disk '$DiskName' attached to VM '$VmName'" -ForegroundColor Green
    Write-Host "💡 Next Steps: initialize and format the disk inside the guest OS (Get-Disk | Where-Object PartitionStyle -eq 'RAW' | Initialize-Disk -PassThru | New-Partition -AssignDriveLetter -UseMaximumSize | Format-Volume)" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
