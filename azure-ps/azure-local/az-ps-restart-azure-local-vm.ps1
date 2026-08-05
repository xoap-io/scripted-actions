<#
.SYNOPSIS
    Restart one or more Azure Local (Azure Stack HCI) virtual machines.

.DESCRIPTION
    This script restarts one or more Arc-managed virtual machines on an Azure Local cluster.
    VMs that are not running are skipped with an info message (start them with
    az-ps-start-azure-local-vm.ps1 instead); failures on single VMs do not abort the batch.
    The script exits with code 1 if any VM failed to restart.

    Uses Get-AzStackHCIVMVirtualMachine and Restart-AzStackHCIVMVirtualMachine.

    This script can run anywhere with an Azure context; it does not need to run on a
    cluster node.

.PARAMETER VmNames
    One or more names of the virtual machines to restart.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER NoWait
    Do not wait for each restart operation to complete.

.EXAMPLE
    .\az-ps-restart-azure-local-vm.ps1 -VmNames "avd-host-01"

.EXAMPLE
    .\az-ps-restart-azure-local-vm.ps1 -VmNames "avd-host-01", "avd-host-02" -NoWait

    Restarts two VMs without waiting for the operations to complete.

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
    [Parameter(Mandatory = $true, HelpMessage = "One or more names of the virtual machines to restart.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$VmNames,

    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "Do not wait for each restart operation to complete.")]
    [switch]$NoWait
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

    $restarted = @()
    $skipped   = @()
    $failed    = @()

    foreach ($vmName in $VmNames) {
        try {
            $vm = Get-AzStackHCIVMVirtualMachine -Name $vmName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
            if (-not $vm) {
                Write-Host "⚠️  VM '$vmName' not found in resource group '$ResourceGroupName' - skipping" -ForegroundColor Yellow
                $failed += $vmName
                continue
            }

            if ("$($vm.StatusPowerState)" -ne 'Running') {
                Write-Host "ℹ️  VM '$vmName' is not running (state: $($vm.StatusPowerState)) - skipping. Use az-ps-start-azure-local-vm.ps1 to start it." -ForegroundColor Yellow
                $skipped += $vmName
                continue
            }

            Write-Host "🔧 Restarting VM '$vmName'..." -ForegroundColor Cyan
            if ($NoWait) {
                $null = Restart-AzStackHCIVMVirtualMachine -Name $vmName -ResourceGroupName $ResourceGroupName -NoWait
                Write-Host "✅ Restart of VM '$vmName' initiated" -ForegroundColor Green
            }
            else {
                $null = Restart-AzStackHCIVMVirtualMachine -Name $vmName -ResourceGroupName $ResourceGroupName
                Write-Host "✅ VM '$vmName' restarted" -ForegroundColor Green
            }
            $restarted += $vmName
        }
        catch {
            Write-Host "❌ Failed to restart VM '$($vmName)': $($_.Exception.Message)" -ForegroundColor Red
            $failed += $vmName
        }
    }

    Write-Host "`n📊 Summary: $($restarted.Count) restarted, $($skipped.Count) skipped, $($failed.Count) failed" -ForegroundColor Blue
    if ($failed.Count -gt 0) {
        throw "The following VMs could not be restarted: $($failed -join ', ')"
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
