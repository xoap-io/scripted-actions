<#
.SYNOPSIS
    List all Arc-managed virtual machines on an Azure Local (Azure Stack HCI) cluster.

.DESCRIPTION
    This script builds an inventory of all Arc-managed virtual machines of an Azure Local
    resource group: power state, provisioning state, vCPU / memory sizing, IP addresses,
    logical network, source image, storage path and data disk count. The result is printed
    as a table and can optionally be exported to a timestamped CSV file.

    Uses Get-AzStackHCIVMVirtualMachine and Get-AzStackHCIVMNetworkInterface.

    This script can run anywhere with an Azure context; it does not need to run on a
    cluster node.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER VmName
    Optional name filter. Supports wildcards, e.g. "avd-*".

.PARAMETER ExportCsv
    Export the inventory to a CSV file in addition to the console output.

.PARAMETER CsvPath
    Path of the CSV export file. Defaults to "azure-local-vms-<timestamp>.csv" in the
    current directory.

.EXAMPLE
    .\az-ps-get-azure-local-vm-inventory.ps1

    Lists all Azure Local VMs in the "AzureLocal" resource group.

.EXAMPLE
    .\az-ps-get-azure-local-vm-inventory.ps1 -VmName "avd-*" -ExportCsv

    Lists all AVD session hosts and exports them to a timestamped CSV file.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.Resources, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM)

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-arc-virtual-machines

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Optional VM name filter. Supports wildcards, e.g. 'avd-*'.")]
    [string]$VmName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Export the inventory to a CSV file in addition to the console output.")]
    [switch]$ExportCsv,

    [Parameter(Mandatory = $false, HelpMessage = "Path of the CSV export file. Defaults to a timestamped file in the current directory.")]
    [string]$CsvPath = ""
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

    # 1) List the Arc machines of the resource group (HCI kind only).
    #    Get-AzResource is used instead of Get-AzStackHCIVMVirtualMachine -ResourceGroupName
    #    because the latter fails on Arc machines with an empty Kind (e.g. Arc-enabled
    #    cluster nodes in the same resource group).
    Write-Host "🔍 Listing Azure Local VMs in resource group '$ResourceGroupName'..." -ForegroundColor Cyan
    $machines = @(Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.HybridCompute/machines' -ErrorAction SilentlyContinue |
        Where-Object { "$($_.Kind)" -eq 'HCI' })
    if ($VmName) {
        $machines = @($machines | Where-Object { $_.Name -like $VmName })
    }

    if ($machines.Count -eq 0) {
        Write-Host "ℹ️  No Azure Local VMs found in resource group '$ResourceGroupName'$(if ($VmName) { " matching '$VmName'" })" -ForegroundColor Yellow
        Write-Host "💡 Next Steps: deploy a VM with az-ps-deploy-azure-local-vm-from-image.ps1" -ForegroundColor Yellow
        return
    }

    # 2) Resolve per-VM instance details (hardware, power state, NICs)
    $inventory = foreach ($machine in $machines) {
        $vm = Get-AzStackHCIVMVirtualMachine -Name $machine.Name -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

        $ipAddresses = @()
        $logicalNetworks = @()
        foreach ($nicRef in @($vm.NetworkProfileNetworkInterface)) {
            if (-not $nicRef.Id) { continue }
            $nicName = ($nicRef.Id -split '/')[-1]
            $nic = Get-AzStackHCIVMNetworkInterface -ResourceGroupName $ResourceGroupName -Name $nicName -ErrorAction SilentlyContinue
            if ($nic) {
                $ipAddresses     += @($nic.IPConfiguration.IPAddress | Where-Object { $_ })
                $logicalNetworks += @($nic.IPConfiguration.SubnetId | Where-Object { $_ } | ForEach-Object { ($_ -split '/')[-1] })
            }
        }

        $imageName = ""
        if ($vm.ImageReferenceId) { $imageName = ($vm.ImageReferenceId -split '/')[-1] }
        $storagePathName = ""
        if ($vm.StorageProfileVMConfigStoragePathId) { $storagePathName = ($vm.StorageProfileVMConfigStoragePathId -split '/')[-1] }

        [PSCustomObject]@{
            Name              = $machine.Name
            PowerState        = "$($vm.StatusPowerState)"
            ProvisioningState = "$($vm.ProvisioningState)"
            vCPU              = $vm.HardwareProfileProcessor
            MemoryMB          = $vm.HardwareProfileMemoryMb
            IPAddresses       = ($ipAddresses | Select-Object -Unique) -join ", "
            LogicalNetwork    = ($logicalNetworks | Select-Object -Unique) -join ", "
            Image             = $imageName
            StoragePath       = $storagePathName
            DataDisks         = @($vm.StorageProfileDataDisk).Count
        }
    }

    # 3) Output
    $inventory | Format-Table -AutoSize | Out-String -Width 4096 | Write-Host

    $running = @($inventory | Where-Object { $_.PowerState -eq 'Running' }).Count
    $stopped = @($inventory | Where-Object { $_.PowerState -eq 'Stopped' }).Count
    Write-Host "📊 Summary: $($machines.Count) VM(s) total, $running running, $stopped stopped" -ForegroundColor Blue

    if ($ExportCsv) {
        if (-not $CsvPath) {
            $CsvPath = Join-Path (Get-Location) "azure-local-vms-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
        }
        $inventory | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding utf8
        Write-Host "✅ Inventory exported to '$CsvPath'" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
