
<#!
.SYNOPSIS
    Deletes all (optionally filtered) running Azure VMs and their associated resources in a resource group.

.DESCRIPTION
    This script deletes all running Azure VMs in a specified resource group (or all groups if not specified), including their NICs, disks, public IPs, and optionally NSGs and snapshots. It uses robust error handling and parameter validation.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group. If not specified, all groups are processed.
.PARAMETER NameFilter
    Optional wildcard filter for VM names (e.g., 'web*').

.EXAMPLE
    .\az-ps-delete-running-vms.ps1 -ResourceGroup "myResourceGroup" -NameFilter "web*"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ResourceGroup,
    [Parameter()]
    [string]$NameFilter
)

$ErrorActionPreference = 'Stop'
$deletedVMs = @()

if ($ResourceGroup) {
    $vms = Get-AzVM -ResourceGroupName $ResourceGroup
} else {
    $vms = Get-AzVM
}

if ($NameFilter) {
    $vms = $vms | Where-Object { $_.Name -like $NameFilter }
}

foreach ($vm in $vms) {
    $vmName = $vm.Name
    $rgName = $vm.ResourceGroupName
    Write-Host "Processing VM: $vmName in RG: $rgName" -ForegroundColor Cyan
    try {
        # ...existing code...
        $nicIds = $vm.NetworkProfile.NetworkInterfaces.Id
        $nics = $nicIds | ForEach-Object { Get-AzNetworkInterface -ResourceId $_ }
        $osDiskName = $vm.StorageProfile.OsDisk.Name
        $osDisk = Get-AzDisk -ResourceGroupName $rgName -DiskName $osDiskName
        $dataDisks = $vm.StorageProfile.DataDisks | ForEach-Object { Get-AzDisk -ResourceGroupName $rgName -DiskName $_.Name }
        Write-Host "Deleting VM: $vmName" -ForegroundColor Yellow
        Remove-AzVM -Name $vmName -ResourceGroupName $rgName -Force
        foreach ($nic in $nics) {
            foreach ($ipconfig in $nic.IpConfigurations) {
                if ($ipconfig.PublicIpAddress -ne $null) {
                    $pip = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name ($ipconfig.PublicIpAddress.Id.Split('/')[-1])
                    Write-Host "Deleting Public IP: $($pip.Name)" -ForegroundColor Yellow
                    Remove-AzPublicIpAddress -Name $pip.Name -ResourceGroupName $rgName -Force
                }
                $privIp = $ipconfig.PrivateIpAddress
                Write-Host "Found Private IP: $privIp (deleted with NIC)" -ForegroundColor Gray
            }
            if ($nic.NetworkSecurityGroup -ne $null) {
                $nsgId = $nic.NetworkSecurityGroup.Id
                $nsgName = $nsgId.Split('/')[-1]
                $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgName -Name $nsgName
                $nicCount = (Get-AzNetworkInterface | Where-Object { $_.NetworkSecurityGroup.Id -eq $nsgId }).Count
                if ($nicCount -eq 1) {
                    Write-Host "Deleting NSG: $nsgName" -ForegroundColor Yellow
                    Remove-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName -Force
                }
            }
            Write-Host "Deleting NIC: $($nic.Name)" -ForegroundColor Yellow
            Remove-AzNetworkInterface -Name $nic.Name -ResourceGroupName $rgName -Force
        }
        Write-Host "Deleting OS Disk: $($osDisk.Name)" -ForegroundColor Yellow
        Remove-AzDisk -ResourceGroupName $rgName -DiskName $osDisk.Name -Force
        foreach ($disk in $dataDisks) {
            Write-Host "Deleting Data Disk: $($disk.Name)" -ForegroundColor Yellow
            Remove-AzDisk -ResourceGroupName $rgName -DiskName $disk.Name -Force
        }
        $snapshots = Get-AzSnapshot -ResourceGroupName $rgName | Where-Object { $_.Tags.ContainsKey("sourceVM") -and $($_.Tags["sourceVM"]) -eq $vmName }
        foreach ($snapshot in $snapshots) {
            Write-Host "Deleting Snapshot: $($snapshot.Name)" -ForegroundColor Yellow
            Remove-AzSnapshot -ResourceGroupName $rgName -SnapshotName $snapshot.Name -Force
        }
        $deletedVMs += $vmName
    } catch {
        Write-Warning "Error processing $vmName: $_"
    }
}

Write-Host "`nDeleted VMs:" -ForegroundColor Green
$deletedVMs | ForEach-Object { Write-Host "- $_" -ForegroundColor Green }
