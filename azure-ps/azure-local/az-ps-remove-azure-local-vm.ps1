<#
.SYNOPSIS
    Remove an Azure Local (Azure Stack HCI) virtual machine including its network
    interfaces and optionally its data disks.

.DESCRIPTION
    This script deletes an Arc-managed virtual machine from an Azure Local cluster. It
    prints an inventory of everything that will be deleted (VM instance + Arc machine
    resource + OS disk, network interfaces, data disks), asks for a typed 'YES'
    confirmation (skip with -Force), captures the NIC and data disk IDs before deletion,
    then removes the VM and its NICs. Data disks are only removed when -RemoveDataDisks is
    specified; pass -KeepNics to keep the network interfaces (e.g. to preserve a static IP
    for a redeployment).

    Removing the VM also deletes the implicit OS disk. NIC/disk removal failures are
    reported as warnings and do not fail the script; the final verification re-queries the
    VM to confirm it is gone.

    Uses Get/Remove-AzStackHCIVMVirtualMachine, Remove-AzStackHCIVMNetworkInterface and
    Remove-AzStackHCIVMVirtualHardDisk.

    This script can run anywhere with an Azure context; it does not need to run on a
    cluster node.

.PARAMETER VmName
    Name of the virtual machine to remove.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER Force
    Skip the typed 'YES' confirmation prompt. Required for non-interactive execution
    (e.g. XOAP Scripted Actions).

.PARAMETER KeepNics
    Keep the network interfaces of the VM instead of deleting them.

.PARAMETER RemoveDataDisks
    Also delete the data disks attached to the VM. Off by default because data disks may
    hold data you want to reattach elsewhere.

.EXAMPLE
    .\az-ps-remove-azure-local-vm.ps1 -VmName "avd-host-01"

    Removes the VM and its NICs after typed confirmation; data disks are kept.

.EXAMPLE
    .\az-ps-remove-azure-local-vm.ps1 -VmName "avd-host-01" -RemoveDataDisks -Force

    Removes the VM, its NICs and its data disks without confirmation.

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
    [Parameter(Mandatory = $true, HelpMessage = "Name of the virtual machine to remove.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Skip the typed 'YES' confirmation prompt.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Keep the network interfaces of the VM instead of deleting them.")]
    [switch]$KeepNics,

    [Parameter(Mandatory = $false, HelpMessage = "Also delete the data disks attached to the VM.")]
    [switch]$RemoveDataDisks
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

    # 1) Resolve the VM and capture attached resource IDs BEFORE deletion
    $vm = Get-AzStackHCIVMVirtualMachine -Name $VmName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $vm) {
        throw "VM '$VmName' not found in resource group '$ResourceGroupName'."
    }

    $nicIds  = @($vm.NetworkProfileNetworkInterface | ForEach-Object { $_.Id } | Where-Object { $_ })
    $diskIds = @($vm.StorageProfileDataDisk | ForEach-Object { $_.Id } | Where-Object { $_ })

    # 2) Show what will be deleted
    Write-Host "`n⚠️  The following resources will be deleted:" -ForegroundColor Yellow
    Write-Host "   - VM instance '$VmName' (power state: $($vm.StatusPowerState)) incl. Arc machine resource and OS disk" -ForegroundColor Yellow
    if (-not $KeepNics) {
        foreach ($nicId in $nicIds) { Write-Host "   - Network interface '$(($nicId -split '/')[-1])'" -ForegroundColor Yellow }
    }
    if ($RemoveDataDisks) {
        foreach ($diskId in $diskIds) { Write-Host "   - Data disk '$(($diskId -split '/')[-1])'" -ForegroundColor Yellow }
    }
    elseif ($diskIds.Count -gt 0) {
        Write-Host "   ($($diskIds.Count) data disk(s) will be kept; pass -RemoveDataDisks to delete them)" -ForegroundColor Yellow
    }

    # 3) Confirmation
    if (-not $Force) {
        $answer = Read-Host "`nType 'YES' to confirm the deletion"
        if ($answer -cne 'YES') {
            Write-Host "ℹ️  Deletion cancelled" -ForegroundColor Yellow
            return
        }
    }

    # 4) Remove the VM (deletes the VM instance, the Arc machine resource and the OS disk)
    Write-Host "🔧 Removing VM '$VmName'..." -ForegroundColor Cyan
    Remove-AzStackHCIVMVirtualMachine -Name $VmName -ResourceGroupName $ResourceGroupName -Confirm:$false
    Write-Host "✅ VM '$VmName' removed" -ForegroundColor Green

    # 5) Remove NICs (unless kept)
    if (-not $KeepNics) {
        foreach ($nicId in $nicIds) {
            $nicName = ($nicId -split '/')[-1]
            try {
                Remove-AzStackHCIVMNetworkInterface -Name $nicName -ResourceGroupName $ResourceGroupName -Confirm:$false
                Write-Host "✅ Network interface '$nicName' removed" -ForegroundColor Green
            }
            catch {
                Write-Host "⚠️  Failed to remove network interface '$($nicName)': $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    # 6) Optionally remove data disks
    if ($RemoveDataDisks) {
        foreach ($diskId in $diskIds) {
            $diskName = ($diskId -split '/')[-1]
            try {
                Remove-AzStackHCIVMVirtualHardDisk -Name $diskName -ResourceGroupName $ResourceGroupName -Confirm:$false
                Write-Host "✅ Data disk '$diskName' removed" -ForegroundColor Green
            }
            catch {
                Write-Host "⚠️  Failed to remove data disk '$($diskName)': $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    }

    # 7) Verification
    $check = Get-AzStackHCIVMVirtualMachine -Name $VmName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if ($check) {
        throw "VM '$VmName' still exists after the removal - check the Azure portal."
    }
    Write-Host "✅ Verified: VM '$VmName' no longer exists" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
