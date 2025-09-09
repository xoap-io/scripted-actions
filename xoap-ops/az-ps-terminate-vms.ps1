<#
.SYNOPSIS
    Stop all running Azure Virtual Machines using Azure PowerShell.

.DESCRIPTION
    This script identifies and stops all running Azure Virtual Machines in a specified resource group or subscription.
    Provides detailed output for each stopped VM including status, size, location, and resource information.
    Supports dry-run mode for validation and selective stopping by VM name patterns.

.PARAMETER ResourceGroupName
    Name of the Azure Resource Group to target. If not specified, all resource groups in the subscription will be checked.

.PARAMETER SubscriptionId
    Azure Subscription ID. If not specified, the current subscription context will be used.

.PARAMETER VMNamePattern
    Pattern to match VM names (supports wildcards). Only VMs matching this pattern will be stopped.

.PARAMETER WhatIf
    Show what VMs would be stopped without actually stopping them (dry-run mode).

.PARAMETER Force
    Skip confirmation prompts and stop VMs immediately.

.PARAMETER Parallel
    Stop VMs in parallel for faster execution when dealing with multiple VMs.

.PARAMETER IncludeDeallocated
    Also show deallocated VMs in the output for comparison.

.EXAMPLE
    .\azure-ps-stop-running-vms.ps1
    
    Stops all running VMs in the current subscription with confirmation prompts.

.EXAMPLE
    .\azure-ps-stop-running-vms.ps1 -ResourceGroupName "prod-rg" -WhatIf
    
    Shows what VMs would be stopped in the 'prod-rg' resource group without actually stopping them.

.EXAMPLE
    .\azure-ps-terminate-vms.ps1 -VMNamePattern "web-*" -Force -Parallel
    
    Stops all running VMs with names starting with 'web-' without confirmation, using parallel execution.

.EXAMPLE
    .\azure-ps-terminate-vms.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -IncludeDeallocated
    
    Stops running VMs in a specific subscription and shows deallocated VMs for comparison.

.NOTES
    Author: Azure PowerShell Script
    Version: 1.0.0
    Requires: Az PowerShell module (Install-Module -Name Az)
    Requires: Azure PowerShell authentication (Connect-AzAccount)

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell Compute
#>

param(
    [Parameter(HelpMessage = "Name of the Azure Resource Group to target")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroupName,

    [Parameter(HelpMessage = "Pattern to match VM names (supports wildcards)")]
    [ValidateNotNullOrEmpty()]
    [string]$VMNamePattern = "*",

    [Parameter(HelpMessage = "Show what VMs would be stopped without actually stopping them")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip confirmation prompts and stop VMs immediately")]
    [switch]$Force,

    [Parameter(HelpMessage = "Stop VMs in parallel for faster execution")]
    [switch]$Parallel,

    [Parameter(HelpMessage = "Also show deallocated VMs in the output for comparison")]
    [switch]$IncludeDeallocated,

    [Parameter(HelpMessage = "Delete VMs")]
    [switch]$DeleteVMs,

    [Parameter(HelpMessage = "Delete managed disks attached to VMs")]
    [switch]$DeleteDisks,

    [Parameter(HelpMessage = "Delete network interfaces attached to VMs")]
    [switch]$DeleteNICs,

    [Parameter(HelpMessage = "Delete public IP addresses attached to VMs")]
    [switch]$DeleteIPs,

    [Parameter(HelpMessage = "Delete resource groups containing VMs")]
    [switch]$DeleteResourceGroups,

    [Parameter(HelpMessage = "Delete network security groups attached to NICs")]
    [switch]$DeleteNSGs
    )

try {
    if (-not $filteredVMs) {
        Write-Host "ℹ️ No virtual machines found matching pattern '$VMNamePattern'" -ForegroundColor Yellow
        return
    }

    # Categorize VMs by power state
    $runningVMs = $filteredVMs | Where-Object { $_.PowerState -eq "VM running" }
    $deallocatedVMs = $filteredVMs | Where-Object { $_.PowerState -eq "VM deallocated" }
    $otherStateVMs = $filteredVMs | Where-Object { $_.PowerState -notin @("VM running", "VM deallocated") }

    Write-Host "`n📊 VM Status Summary:" -ForegroundColor White
    Write-Host "   🟢 Running VMs: $($runningVMs.Count)" -ForegroundColor Green
    Write-Host "   🔴 Deallocated VMs: $($deallocatedVMs.Count)" -ForegroundColor Red
    Write-Host "   🟡 Other States: $($otherStateVMs.Count)" -ForegroundColor Yellow
    Write-Host "   📦 Total VMs: $($filteredVMs.Count)" -ForegroundColor Cyan

    # Show deallocated VMs if requested
    if ($IncludeDeallocated -and $deallocatedVMs.Count -gt 0) {
        Write-Host "`n🔴 Deallocated VMs (for reference):" -ForegroundColor Red
        $deallocatedVMs | ForEach-Object {
            Write-Host "   • $($_.Name) [$($_.HardwareProfile.VmSize)] in $($_.ResourceGroupName)" -ForegroundColor Gray
        }
    }

    # Show other state VMs
    if ($otherStateVMs.Count -gt 0) {
        Write-Host "`n🟡 VMs in other states:" -ForegroundColor Yellow
        $otherStateVMs | ForEach-Object {
            Write-Host "   • $($_.Name) [$($_.PowerState)] in $($_.ResourceGroupName)" -ForegroundColor Gray
        }
    }

    if ($runningVMs.Count -eq 0) {
        Write-Host "`nℹ️ No running VMs found to stop" -ForegroundColor Yellow
        return
    }

    # Display running VMs that will be stopped
    Write-Host "`n🟢 Running VMs that will be stopped:" -ForegroundColor Green
    $runningVMs | ForEach-Object {
        Write-Host "   • $($_.Name)" -ForegroundColor White
        Write-Host "     └─ Size: $($_.HardwareProfile.VmSize)" -ForegroundColor Gray
        Write-Host "     └─ Resource Group: $($_.ResourceGroupName)" -ForegroundColor Gray
        Write-Host "     └─ Location: $($_.Location)" -ForegroundColor Gray
        if ($_.Tags) {
            $tagString = ($_.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "
            Write-Host "     └─ Tags: $tagString" -ForegroundColor Gray
        }
    }

    # WhatIf mode - exit without stopping
    if ($WhatIf) {
        Write-Host "`n🔍 WhatIf mode: No VMs will be stopped" -ForegroundColor Cyan
        Write-Host "   $($runningVMs.Count) VMs would be stopped" -ForegroundColor Yellow
        return
    }

    # Confirmation prompt (unless Force is specified)
    if (-not $Force) {
        Write-Host "`n⚠️ Warning: This will stop $($runningVMs.Count) running VM(s)" -ForegroundColor Yellow
        $confirmation = Read-Host "Continue? (y/N)"
        if ($confirmation -notmatch '^[Yy]$') {
            Write-Host "❌ Operation cancelled by user" -ForegroundColor Red
            return
        }
    }

    $stopResults = @()
    $deleteResults = @()
    # Stop or delete VMs
    if ($DeleteVMs) {
        Write-Host "`n🛑 Deleting virtual machines..." -ForegroundColor Cyan
        foreach ($vm in $runningVMs) {
            try {
                Write-Host "   Deleting VM: $($vm.Name)" -ForegroundColor Yellow
                Remove-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
                $deleteResults += @{ VMName = $vm.Name; ResourceGroupName = $vm.ResourceGroupName; Success = $true; Status = "Deleted"; Error = $null }
                Write-Host "   ✅ Successfully deleted: $($vm.Name)" -ForegroundColor Green
            } catch {
                $deleteResults += @{ VMName = $vm.Name; ResourceGroupName = $vm.ResourceGroupName; Success = $false; Status = "Failed"; Error = $_.Exception.Message }
                Write-Host "   ❌ Failed to delete: $($vm.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "`n🛑 Stopping virtual machines..." -ForegroundColor Cyan
        foreach ($vm in $runningVMs) {
            try {
                Write-Host "   Stopping: $($vm.Name)" -ForegroundColor Yellow
                $stopResult = Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force
                $stopResults += @{ VMName = $vm.Name; ResourceGroupName = $vm.ResourceGroupName; Success = $stopResult.IsSuccessStatusCode; Status = "Stopped"; Error = $null }
                Write-Host "   ✅ Successfully stopped: $($vm.Name)" -ForegroundColor Green
            } catch {
                $stopResults += @{ VMName = $vm.Name; ResourceGroupName = $vm.ResourceGroupName; Success = $false; Status = "Failed"; Error = $_.Exception.Message }
                Write-Host "   ❌ Failed to stop: $($vm.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }

    # Delete managed disks
    if ($DeleteDisks) {
        Write-Host "`n🗑 Deleting managed disks attached to VMs..." -ForegroundColor Cyan
        $diskIds = $runningVMs | ForEach-Object { $_.StorageProfile.OsDisk.ManagedDisk.Id } + ($runningVMs | ForEach-Object { $_.StorageProfile.DataDisks.ManagedDisk.Id })
        $diskIds = $diskIds | Where-Object { $_ }
        $deletedDisks = @()
        foreach ($diskId in $diskIds) {
            $disk = Get-AzDisk -ResourceId $diskId
            try {
                Remove-AzDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.Name -Force
                Write-Host "   Deleted disk: $($disk.Name)" -ForegroundColor Green
                $deletedDisks += $disk.Name
            } catch {
                Write-Host "   Failed to delete disk: $($disk.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        if ($deletedDisks) {
            Write-Host "Deleted disks: $($deletedDisks -join ', ')"
        } else {
            Write-Host "No disks deleted."
        }
    }

    # Delete NICs
    if ($DeleteNICs) {
        Write-Host "`n🗑 Deleting network interfaces attached to VMs..." -ForegroundColor Cyan
        $nicIds = $runningVMs | ForEach-Object { $_.NetworkProfile.NetworkInterfaces.Id }
        $nicIds = $nicIds | Where-Object { $_ }
        $deletedNICs = @()
        foreach ($nicId in $nicIds) {
            $nic = Get-AzNetworkInterface -ResourceId $nicId
            try {
                Remove-AzNetworkInterface -ResourceGroupName $nic.ResourceGroupName -Name $nic.Name -Force
                Write-Host "   Deleted NIC: $($nic.Name)" -ForegroundColor Green
                $deletedNICs += $nic.Name
            } catch {
                Write-Host "   Failed to delete NIC: $($nic.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        if ($deletedNICs) {
            Write-Host "Deleted NICs: $($deletedNICs -join ', ')"
        } else {
            Write-Host "No NICs deleted."
        }
    }

    # Delete public IPs
    if ($DeleteIPs) {
        Write-Host "`n🗑 Deleting public IP addresses attached to VMs..." -ForegroundColor Cyan
        $nicIds = $runningVMs | ForEach-Object { $_.NetworkProfile.NetworkInterfaces.Id }
        $nicIds = $nicIds | Where-Object { $_ }
        $deletedIPs = @()
        foreach ($nicId in $nicIds) {
            $nic = Get-AzNetworkInterface -ResourceId $nicId
            foreach ($ipConfig in $nic.IpConfigurations) {
                if ($ipConfig.PublicIpAddress) {
                    $pubIp = Get-AzPublicIpAddress -ResourceId $ipConfig.PublicIpAddress.Id
                    try {
                        Remove-AzPublicIpAddress -ResourceGroupName $pubIp.ResourceGroupName -Name $pubIp.Name -Force
                        Write-Host "   Deleted Public IP: $($pubIp.Name)" -ForegroundColor Green
                        $deletedIPs += $pubIp.Name
                    } catch {
                        Write-Host "   Failed to delete Public IP: $($pubIp.Name) - $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
            }
        }
        if ($deletedIPs) {
            Write-Host "Deleted Public IPs: $($deletedIPs -join ', ')"
        } else {
            Write-Host "No Public IPs deleted."
        }
    }

    # Delete NSGs
    if ($DeleteNSGs) {
        Write-Host "`n🗑 Deleting network security groups attached to NICs..." -ForegroundColor Cyan
        $nicIds = $runningVMs | ForEach-Object { $_.NetworkProfile.NetworkInterfaces.Id }
        $nicIds = $nicIds | Where-Object { $_ }
        $deletedNSGs = @()
        foreach ($nicId in $nicIds) {
            $nic = Get-AzNetworkInterface -ResourceId $nicId
            if ($nic.NetworkSecurityGroup) {
                $nsg = Get-AzNetworkSecurityGroup -ResourceId $nic.NetworkSecurityGroup.Id
                try {
                    Remove-AzNetworkSecurityGroup -ResourceGroupName $nsg.ResourceGroupName -Name $nsg.Name -Force
                    Write-Host "   Deleted NSG: $($nsg.Name)" -ForegroundColor Green
                    $deletedNSGs += $nsg.Name
                } catch {
                    Write-Host "   Failed to delete NSG: $($nsg.Name) - $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        if ($deletedNSGs) {
            Write-Host "Deleted NSGs: $($deletedNSGs -join ', ')"
        } else {
            Write-Host "No NSGs deleted."
        }
    }

    # Delete resource groups
    if ($DeleteResourceGroups) {
        Write-Host "`n🗑 Deleting resource groups containing VMs..." -ForegroundColor Cyan
        $rgNames = $runningVMs | ForEach-Object { $_.ResourceGroupName } | Select-Object -Unique
        $deletedRGs = @()
        foreach ($rgName in $rgNames) {
            try {
                Remove-AzResourceGroup -Name $rgName -Force
                Write-Host "   Deleted Resource Group: $rgName" -ForegroundColor Green
                $deletedRGs += $rgName
            } catch {
                Write-Host "   Failed to delete Resource Group: $rgName - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        if ($deletedRGs) {
            Write-Host "Deleted Resource Groups: $($deletedRGs -join ', ')"
        } else {
            Write-Host "No Resource Groups deleted."
        }
    }

    # Display detailed results
    Write-Host "`n📋 Detailed Stop Results:" -ForegroundColor White
    $successfulStops = $stopResults | Where-Object { $_.Success }
    $failedStops = $stopResults | Where-Object { -not $_.Success }

    if ($successfulStops.Count -gt 0) {
        Write-Host "`n✅ Successfully Stopped VMs ($($successfulStops.Count)):" -ForegroundColor Green
        foreach ($result in $successfulStops) {
            $vmDetails = $runningVMs | Where-Object { $_.Name -eq $result.VMName }
            Write-Host "   • $($result.VMName)" -ForegroundColor White
            Write-Host "     └─ Resource Group: $($result.ResourceGroupName)" -ForegroundColor Gray
            Write-Host "     └─ Size: $($vmDetails.HardwareProfile.VmSize)" -ForegroundColor Gray
            Write-Host "     └─ Location: $($vmDetails.Location)" -ForegroundColor Gray
            Write-Host "     └─ Status: Deallocated" -ForegroundColor Gray
        }
    }

    if ($failedStops.Count -gt 0) {
        Write-Host "`n❌ Failed to Stop VMs ($($failedStops.Count)):" -ForegroundColor Red
        foreach ($result in $failedStops) {
            Write-Host "   • $($result.VMName)" -ForegroundColor White
            Write-Host "     └─ Resource Group: $($result.ResourceGroupName)" -ForegroundColor Gray
            Write-Host "     └─ Error: $($result.Error)" -ForegroundColor Red
        }
    }

    # Summary
    Write-Host "`n📊 Operation Summary:" -ForegroundColor White
    Write-Host "   🎯 Target VMs: $($runningVMs.Count)" -ForegroundColor Cyan
    Write-Host "   ✅ Successfully Stopped: $($successfulStops.Count)" -ForegroundColor Green
    Write-Host "   ❌ Failed: $($failedStops.Count)" -ForegroundColor Red
    
    if ($successfulStops.Count -gt 0) {
        Write-Host "`n💰 Cost Savings: VMs are now deallocated and not incurring compute charges" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script execution failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Gray
    exit 1
}