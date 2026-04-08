<#
.SYNOPSIS
    Stop or delete all running Azure Virtual Machines using Azure PowerShell.

.DESCRIPTION
    This script discovers and stops or deletes all running Azure Virtual Machines in a
    specified resource group or across an entire subscription. Optionally removes
    associated managed disks, NICs, public IPs, NSGs, and resource groups.
    Writes a detailed log file recording every resource that was removed.
    Includes post-operation verification to confirm no targeted VMs remain running.

    The script uses the Az PowerShell module cmdlets:
    Get-AzVM, Stop-AzVM, Remove-AzVM, and related Az.Network/Az.Compute cmdlets.

.PARAMETER SubscriptionId
    Azure Subscription ID to target. If not specified, the current Az context is used.

.PARAMETER ResourceGroupName
    Name of the Azure Resource Group to target. If not specified, all resource groups
    in the subscription are checked.

.PARAMETER VMNamePattern
    Wildcard pattern to match VM names. Defaults to '*' (all VMs).

.PARAMETER WhatIf
    Show what VMs would be actioned without making any changes.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER DeleteVMs
    Permanently delete VMs instead of just deallocating them.

.PARAMETER DeleteDisks
    Delete managed disks attached to the targeted VMs.

.PARAMETER DeleteNICs
    Delete network interfaces attached to the targeted VMs.

.PARAMETER DeleteIPs
    Delete public IP addresses attached to the targeted VMs.

.PARAMETER DeleteNSGs
    Delete network security groups attached to NIC of the targeted VMs.

.PARAMETER DeleteResourceGroups
    Delete the resource groups containing the targeted VMs.

.PARAMETER IncludeDeallocated
    Include already-deallocated VMs in the console output for reference.

.EXAMPLE
    .\az-ps-terminate-vms.ps1 -WhatIf
    Shows all running VMs in the current subscription without making changes.

.EXAMPLE
    .\az-ps-terminate-vms.ps1 -ResourceGroupName "rg-dev" -Force
    Deallocates all running VMs in the rg-dev resource group without confirmation.

.EXAMPLE
    .\az-ps-terminate-vms.ps1 -SubscriptionId "12345678-0000-0000-0000-000000000000" -DeleteVMs -DeleteDisks -DeleteNICs -DeleteIPs -Force
    Permanently deletes all VMs and associated resources in the specified subscription.

.EXAMPLE
    .\az-ps-terminate-vms.ps1 -VMNamePattern "dev-*" -DeleteVMs -Force
    Permanently deletes all running VMs whose names start with 'dev-'.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module -Name Az)

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.compute/get-azvm

.COMPONENT
    Azure PowerShell Compute
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Azure Subscription ID to target")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(HelpMessage = "Name of the Azure Resource Group to target")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroupName,

    [Parameter(HelpMessage = "Wildcard pattern to match VM names")]
    [string]$VMNamePattern = '*',

    [Parameter(HelpMessage = "Show what VMs would be actioned without making changes")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(HelpMessage = "Permanently delete VMs instead of deallocating")]
    [switch]$DeleteVMs,

    [Parameter(HelpMessage = "Delete managed disks attached to the targeted VMs")]
    [switch]$DeleteDisks,

    [Parameter(HelpMessage = "Delete network interfaces attached to the targeted VMs")]
    [switch]$DeleteNICs,

    [Parameter(HelpMessage = "Delete public IP addresses attached to the targeted VMs")]
    [switch]$DeleteIPs,

    [Parameter(HelpMessage = "Delete NSGs attached to NICs of the targeted VMs")]
    [switch]$DeleteNSGs,

    [Parameter(HelpMessage = "Delete resource groups containing the targeted VMs")]
    [switch]$DeleteResourceGroups,

    [Parameter(HelpMessage = "Include already-deallocated VMs in output for reference")]
    [switch]$IncludeDeallocated
)

$ErrorActionPreference = 'Stop'

$LogFile = "az-ps-terminate-vms-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS', 'ACTION')]
        [string]$Level = 'INFO',
        [string]$Color = 'White'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    Write-Host $Message -ForegroundColor $Color
}

try {
    Write-Log '===== Azure VM Termination Script Started =====' -Level INFO -Color Blue
    Write-Log "Log file: $(Resolve-Path $LogFile -ErrorAction SilentlyContinue)$LogFile" -Level INFO -Color Cyan

    # Verify Az module
    if (-not (Get-Module -ListAvailable -Name Az.Compute)) {
        throw "Az.Compute module not found. Install with: Install-Module -Name Az"
    }

    # Set subscription context if specified
    if ($SubscriptionId) {
        Write-Log "Setting subscription context: $SubscriptionId" -Level INFO -Color Cyan
        Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
    }

    $context = Get-AzContext
    if (-not $context) {
        throw "Not authenticated to Azure. Run Connect-AzAccount first."
    }

    Write-Log "Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level INFO -Color Cyan
    Write-Log "Tenant:       $($context.Tenant.Id)" -Level INFO -Color Cyan

    # Discover VMs with power state
    Write-Log '🔍 Discovering virtual machines...' -Level INFO -Color Cyan

    $getParams = @{ Status = $true }
    if ($ResourceGroupName) { $getParams['ResourceGroupName'] = $ResourceGroupName }

    $allVMs = @(Get-AzVM @getParams)
    $filteredVMs = @($allVMs | Where-Object { $_.Name -like $VMNamePattern })

    Write-Log "Discovered $($allVMs.Count) total VM(s); $($filteredVMs.Count) match pattern '$VMNamePattern'" -Level INFO -Color Cyan

    if ($filteredVMs.Count -eq 0) {
        Write-Log "ℹ️ No virtual machines found matching pattern '$VMNamePattern'. Exiting." -Level INFO -Color Yellow
        exit 0
    }

    # Categorise
    $runningVMs     = @($filteredVMs | Where-Object { $_.PowerState -eq 'VM running' })
    $deallocatedVMs = @($filteredVMs | Where-Object { $_.PowerState -eq 'VM deallocated' })
    $otherVMs       = @($filteredVMs | Where-Object { $_.PowerState -notin @('VM running', 'VM deallocated') })

    Write-Log '' -Level INFO -Color White
    Write-Log '📊 VM Status Summary:' -Level INFO -Color White
    Write-Log "   🟢 Running:     $($runningVMs.Count)" -Level INFO -Color Green
    Write-Log "   ⚪ Deallocated: $($deallocatedVMs.Count)" -Level INFO -Color Gray
    Write-Log "   🟡 Other:       $($otherVMs.Count)" -Level INFO -Color Yellow

    if ($IncludeDeallocated -and $deallocatedVMs.Count -gt 0) {
        Write-Log '' -Level INFO -Color White
        Write-Log '⚪ Deallocated VMs (reference):' -Level INFO -Color Gray
        foreach ($vm in $deallocatedVMs) {
            Write-Log "   • $($vm.Name) | $($vm.HardwareProfile.VmSize) | $($vm.ResourceGroupName)" -Level INFO -Color Gray
        }
    }

    if ($otherVMs.Count -gt 0) {
        Write-Log '' -Level INFO -Color White
        Write-Log '🟡 VMs in other states:' -Level WARN -Color Yellow
        foreach ($vm in $otherVMs) {
            Write-Log "   • $($vm.Name) [$($vm.PowerState)] | $($vm.ResourceGroupName)" -Level WARN -Color Yellow
        }
    }

    if ($runningVMs.Count -eq 0) {
        Write-Log '' -Level INFO -Color White
        Write-Log 'ℹ️ No running VMs found. All targeted VMs are already stopped or deallocated.' -Level INFO -Color Yellow
        exit 0
    }

    Write-Log '' -Level INFO -Color White
    Write-Log '🟢 Running VMs targeted for action:' -Level INFO -Color Green
    foreach ($vm in $runningVMs) {
        Write-Log "   • $($vm.Name)" -Level INFO -Color White
        Write-Log "     Size:           $($vm.HardwareProfile.VmSize)" -Level INFO -Color Gray
        Write-Log "     Resource Group: $($vm.ResourceGroupName)" -Level INFO -Color Gray
        Write-Log "     Location:       $($vm.Location)" -Level INFO -Color Gray
        if ($vm.Tags -and $vm.Tags.Count -gt 0) {
            $tagStr = ($vm.Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
            Write-Log "     Tags:           $tagStr" -Level INFO -Color Gray
        }
    }

    # WhatIf — exit without changes
    if ($WhatIf) {
        Write-Log '' -Level INFO -Color White
        Write-Log "🔍 WhatIf mode — no changes made. $($runningVMs.Count) VM(s) would be actioned." -Level INFO -Color Cyan
        exit 0
    }

    # Confirmation
    if (-not $Force) {
        $action = if ($DeleteVMs) { 'PERMANENTLY DELETE' } else { 'DEALLOCATE' }
        Write-Log '' -Level INFO -Color White
        Write-Log "⚠️  You are about to $action $($runningVMs.Count) VM(s) in subscription '$($context.Subscription.Name)'" -Level WARN -Color Yellow
        $confirmation = Read-Host "Type 'YES' to confirm"
        if ($confirmation -ne 'YES') {
            Write-Log 'Operation cancelled by user.' -Level INFO -Color Yellow
            exit 0
        }
    }

    $actionResults = [System.Collections.Generic.List[PSCustomObject]]::new()

    # Stop or delete VMs
    if ($DeleteVMs) {
        Write-Log '' -Level INFO -Color White
        Write-Log '🛑 Permanently deleting VMs...' -Level ACTION -Color Cyan
        foreach ($vm in $runningVMs) {
            try {
                Write-Log "   Deleting: $($vm.Name) ($($vm.ResourceGroupName))..." -Level ACTION -Color Yellow
                Remove-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force | Out-Null
                Write-Log "   ✅ Deleted: $($vm.Name)" -Level SUCCESS -Color Green
                $actionResults.Add([PSCustomObject]@{
                    VMName        = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Location      = $vm.Location
                    Size          = $vm.HardwareProfile.VmSize
                    Action        = 'Deleted'
                    Success       = $true
                    Error         = $null
                })
            }
            catch {
                Write-Log "   ❌ Failed to delete $($vm.Name): $($_.Exception.Message)" -Level ERROR -Color Red
                $actionResults.Add([PSCustomObject]@{
                    VMName        = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Location      = $vm.Location
                    Size          = $vm.HardwareProfile.VmSize
                    Action        = 'Delete'
                    Success       = $false
                    Error         = $_.Exception.Message
                })
            }
        }
    }
    else {
        Write-Log '' -Level INFO -Color White
        Write-Log '🛑 Deallocating VMs...' -Level ACTION -Color Cyan
        foreach ($vm in $runningVMs) {
            try {
                Write-Log "   Stopping: $($vm.Name) ($($vm.ResourceGroupName))..." -Level ACTION -Color Yellow
                Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force | Out-Null
                Write-Log "   ✅ Deallocated: $($vm.Name)" -Level SUCCESS -Color Green
                $actionResults.Add([PSCustomObject]@{
                    VMName        = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Location      = $vm.Location
                    Size          = $vm.HardwareProfile.VmSize
                    Action        = 'Deallocated'
                    Success       = $true
                    Error         = $null
                })
            }
            catch {
                Write-Log "   ❌ Failed to stop $($vm.Name): $($_.Exception.Message)" -Level ERROR -Color Red
                $actionResults.Add([PSCustomObject]@{
                    VMName        = $vm.Name
                    ResourceGroup = $vm.ResourceGroupName
                    Location      = $vm.Location
                    Size          = $vm.HardwareProfile.VmSize
                    Action        = 'Stop'
                    Success       = $false
                    Error         = $_.Exception.Message
                })
            }
        }
    }

    # Delete managed disks
    if ($DeleteDisks) {
        Write-Log '' -Level INFO -Color White
        Write-Log '🗑️ Deleting managed disks...' -Level ACTION -Color Cyan
        $diskIds = @(
            $runningVMs | ForEach-Object { $_.StorageProfile.OsDisk.ManagedDisk.Id }
            $runningVMs | ForEach-Object { $_.StorageProfile.DataDisks | ForEach-Object { $_.ManagedDisk.Id } }
        ) | Where-Object { $_ }

        foreach ($diskId in $diskIds) {
            try {
                $disk = Get-AzDisk -ResourceId $diskId
                Remove-AzDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.Name -Force | Out-Null
                Write-Log "   ✅ Deleted disk: $($disk.Name) ($($disk.ResourceGroupName))" -Level SUCCESS -Color Green
            }
            catch {
                Write-Log "   ❌ Failed to delete disk $($diskId): $($_.Exception.Message)" -Level ERROR -Color Red
            }
        }
    }

    # Delete NICs
    if ($DeleteNICs) {
        Write-Log '' -Level INFO -Color White
        Write-Log '🗑️ Deleting network interfaces...' -Level ACTION -Color Cyan
        $nicIds = @($runningVMs | ForEach-Object { $_.NetworkProfile.NetworkInterfaces.Id }) | Where-Object { $_ }

        foreach ($nicId in $nicIds) {
            try {
                $nic = Get-AzNetworkInterface -ResourceId $nicId
                Remove-AzNetworkInterface -ResourceGroupName $nic.ResourceGroupName -Name $nic.Name -Force | Out-Null
                Write-Log "   ✅ Deleted NIC: $($nic.Name) ($($nic.ResourceGroupName))" -Level SUCCESS -Color Green
            }
            catch {
                Write-Log "   ❌ Failed to delete NIC $($nicId): $($_.Exception.Message)" -Level ERROR -Color Red
            }
        }
    }

    # Delete public IPs
    if ($DeleteIPs) {
        Write-Log '' -Level INFO -Color White
        Write-Log '🗑️ Deleting public IP addresses...' -Level ACTION -Color Cyan
        $nicIds = @($runningVMs | ForEach-Object { $_.NetworkProfile.NetworkInterfaces.Id }) | Where-Object { $_ }

        foreach ($nicId in $nicIds) {
            try {
                $nic = Get-AzNetworkInterface -ResourceId $nicId
                foreach ($ipConfig in $nic.IpConfigurations) {
                    if ($ipConfig.PublicIpAddress) {
                        $pubIp = Get-AzPublicIpAddress -ResourceId $ipConfig.PublicIpAddress.Id
                        Remove-AzPublicIpAddress -ResourceGroupName $pubIp.ResourceGroupName -Name $pubIp.Name -Force | Out-Null
                        Write-Log "   ✅ Released public IP: $($pubIp.Name) ($($pubIp.IpAddress))" -Level SUCCESS -Color Green
                    }
                }
            }
            catch {
                Write-Log "   ❌ Failed to delete public IPs for NIC $($nicId): $($_.Exception.Message)" -Level ERROR -Color Red
            }
        }
    }

    # Delete NSGs
    if ($DeleteNSGs) {
        Write-Log '' -Level INFO -Color White
        Write-Log '🗑️ Deleting network security groups...' -Level ACTION -Color Cyan
        $nicIds = @($runningVMs | ForEach-Object { $_.NetworkProfile.NetworkInterfaces.Id }) | Where-Object { $_ }

        foreach ($nicId in $nicIds) {
            try {
                $nic = Get-AzNetworkInterface -ResourceId $nicId
                if ($nic.NetworkSecurityGroup) {
                    $nsg = Get-AzNetworkSecurityGroup -ResourceId $nic.NetworkSecurityGroup.Id
                    Remove-AzNetworkSecurityGroup -ResourceGroupName $nsg.ResourceGroupName -Name $nsg.Name -Force | Out-Null
                    Write-Log "   ✅ Deleted NSG: $($nsg.Name) ($($nsg.ResourceGroupName))" -Level SUCCESS -Color Green
                }
            }
            catch {
                Write-Log "   ❌ Failed to delete NSG for NIC $($nicId): $($_.Exception.Message)" -Level ERROR -Color Red
            }
        }
    }

    # Delete resource groups
    if ($DeleteResourceGroups) {
        Write-Log '' -Level INFO -Color White
        Write-Log '🗑️ Deleting resource groups...' -Level ACTION -Color Cyan
        $rgNames = @($runningVMs | ForEach-Object { $_.ResourceGroupName } | Select-Object -Unique)

        foreach ($rgName in $rgNames) {
            try {
                Remove-AzResourceGroup -Name $rgName -Force | Out-Null
                Write-Log "   ✅ Deleted resource group: $rgName" -Level SUCCESS -Color Green
            }
            catch {
                Write-Log "   ❌ Failed to delete resource group $($rgName): $($_.Exception.Message)" -Level ERROR -Color Red
            }
        }
    }

    # Post-operation verification
    if (-not $DeleteVMs -and -not $DeleteResourceGroups) {
        Write-Log '' -Level INFO -Color White
        Write-Log '🔎 Verifying VM states post-operation...' -Level INFO -Color Cyan
        Start-Sleep -Seconds 10  # Allow state to propagate

        $verifyParams = @{ Status = $true }
        if ($ResourceGroupName) { $verifyParams['ResourceGroupName'] = $ResourceGroupName }

        $targetNames = $runningVMs | Select-Object -ExpandProperty Name
        $verifiedVMs = @(Get-AzVM @verifyParams | Where-Object { $_.Name -in $targetNames })
        $stillRunning = @($verifiedVMs | Where-Object { $_.PowerState -eq 'VM running' })

        if ($stillRunning.Count -gt 0) {
            foreach ($vm in $stillRunning) {
                Write-Log "   ⚠️  VM still running: $($vm.Name) ($($vm.ResourceGroupName))" -Level WARN -Color Yellow
            }
            Write-Log "   ⚠️  $($stillRunning.Count) VM(s) are still in running state — manual investigation required." -Level WARN -Color Yellow
        }
        else {
            Write-Log "   ✅ Verified: all $($runningVMs.Count) targeted VM(s) are no longer running." -Level SUCCESS -Color Green
        }
    }

    # Final summary
    $succeeded = @($actionResults | Where-Object { $_.Success })
    $failed    = @($actionResults | Where-Object { -not $_.Success })

    Write-Log '' -Level INFO -Color White
    Write-Log '===== Operation Summary =====' -Level INFO -Color White
    Write-Log "Subscription:   $($context.Subscription.Name) ($($context.Subscription.Id))" -Level INFO -Color White
    Write-Log "VMs Targeted:   $($runningVMs.Count)" -Level INFO -Color Cyan
    Write-Log "✅ Succeeded:   $($succeeded.Count)" -Level SUCCESS -Color Green

    if ($failed.Count -gt 0) {
        Write-Log "❌ Failed:      $($failed.Count)" -Level ERROR -Color Red
        foreach ($f in $failed) {
            Write-Log "   • $($f.VMName): $($f.Error)" -Level ERROR -Color Red
        }
    }
    else {
        Write-Log "❌ Failed:      0" -Level INFO -Color White
    }

    Write-Log "Log file:       $LogFile" -Level INFO -Color Gray
    Write-Log '=============================' -Level INFO -Color White
}
catch {
    Write-Log "❌ Script failed: $($_.Exception.Message)" -Level ERROR -Color Red
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level ERROR -Color Gray
    exit 1
}
finally {
    Write-Log '' -Level INFO -Color White
    Write-Log '🏁 Script execution completed' -Level INFO -Color Green
}
