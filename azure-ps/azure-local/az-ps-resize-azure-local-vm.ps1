<#
.SYNOPSIS
    Resize an Azure Local (Azure Stack HCI) virtual machine (vCPU and/or memory).

.DESCRIPTION
    This script changes the number of vCPUs and/or the memory of an Arc-managed virtual
    machine on an Azure Local cluster. Hardware profile changes require the VM to be powered
    off: if the VM is running, the script stops it first (after confirmation, or
    automatically with -Force) and starts it again afterwards when -Restart is specified.

    At least one of -VmVcpu or -VmMemoryGB must be provided.

    Uses Get/Stop/Update/Start-AzStackHCIVMVirtualMachine.

    This script can run anywhere with an Azure context; it does not need to run on a
    cluster node.

.PARAMETER VmName
    Name of the virtual machine to resize.

.PARAMETER ResourceGroupName
    Azure resource group that represents your Azure Local instance scope. Defaults to "AzureLocal".

.PARAMETER VmVcpu
    New number of vCPUs. Omit to keep the current value.

.PARAMETER VmMemoryGB
    New memory size in GB. Omit to keep the current value.

.PARAMETER Restart
    Start the VM again after the resize if it was running before.

.PARAMETER Force
    Stop a running VM without asking for confirmation. Required for non-interactive
    execution (e.g. XOAP Scripted Actions).

.EXAMPLE
    .\az-ps-resize-azure-local-vm.ps1 -VmName "avd-host-01" -VmVcpu 8 -VmMemoryGB 16 -Restart -Force

    Stops the VM if needed, sets 8 vCPUs / 16 GB and starts it again.

.EXAMPLE
    .\az-ps-resize-azure-local-vm.ps1 -VmName "avd-host-01" -VmMemoryGB 32

    Changes only the memory; asks before stopping a running VM and leaves it stopped.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.Accounts, Az.StackHCIVM 1.1.0+ (Install-Module Az.StackHCIVM)

    The new size must fit on the cluster nodes; on a nested LocalBox environment stay well
    below the host memory (2-node cluster, check free memory on AzLHOST1/AzLHOST2).

.LINK
    https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-arc-virtual-machines

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/

.COMPONENT
    Azure PowerShell Stack HCI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the virtual machine to resize.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "Azure resource group that represents your Azure Local instance scope.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "AzureLocal",

    [Parameter(Mandatory = $false, HelpMessage = "New number of vCPUs. Omit to keep the current value.")]
    [ValidateRange(1, 128)]
    [int]$VmVcpu = 0,

    [Parameter(Mandatory = $false, HelpMessage = "New memory size in GB. Omit to keep the current value.")]
    [ValidateRange(1, 2048)]
    [int]$VmMemoryGB = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Start the VM again after the resize if it was running before.")]
    [switch]$Restart,

    [Parameter(Mandatory = $false, HelpMessage = "Stop a running VM without asking for confirmation.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    # 0) Preflight: module + Azure context + input validation
    if (-not (Get-Module -ListAvailable -Name Az.StackHCIVM)) {
        throw "The Az.StackHCIVM module is not installed. Run: Install-Module Az.StackHCIVM -Scope CurrentUser"
    }
    if ($VmVcpu -eq 0 -and $VmMemoryGB -eq 0) {
        throw "Nothing to do: provide -VmVcpu and/or -VmMemoryGB."
    }
    $context = Get-AzContext
    if (-not $context) {
        throw "No Azure context found. Run Connect-AzAccount (or sign in with your service principal) first."
    }
    Write-Host "🔍 Using subscription '$($context.Subscription.Name)' ($($context.Subscription.Id))" -ForegroundColor Cyan

    # 1) Resolve the VM and record the current state
    $vm = Get-AzStackHCIVMVirtualMachine -Name $VmName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $vm) {
        throw "VM '$VmName' not found in resource group '$ResourceGroupName'."
    }
    $oldVcpu    = $vm.HardwareProfileProcessor
    $oldMemMb   = $vm.HardwareProfileMemoryMb
    $wasRunning = ("$($vm.StatusPowerState)" -eq 'Running')
    Write-Host "🔍 Current size: $oldVcpu vCPU / $([math]::Round($oldMemMb / 1024, 1)) GB (power state: $($vm.StatusPowerState))" -ForegroundColor Cyan

    # 2) Stop the VM if it is running (hardware changes require a powered-off VM)
    if ($wasRunning) {
        if (-not $Force) {
            $answer = Read-Host "VM '$VmName' is running and must be stopped for the resize. Type 'YES' to stop it now"
            if ($answer -cne 'YES') {
                Write-Host "ℹ️  Resize cancelled" -ForegroundColor Yellow
                return
            }
        }
        Write-Host "🔧 Stopping VM '$VmName'..." -ForegroundColor Cyan
        $null = Stop-AzStackHCIVMVirtualMachine -Name $VmName -ResourceGroupName $ResourceGroupName
        Write-Host "✅ VM stopped" -ForegroundColor Green
    }

    # 3) Apply the new hardware profile
    $updateParams = @{
        Name              = $VmName
        ResourceGroupName = $ResourceGroupName
    }
    if ($VmVcpu -gt 0)     { $updateParams['VmProcessor']  = $VmVcpu }
    if ($VmMemoryGB -gt 0) { $updateParams['VmMemoryInMB'] = [int64]($VmMemoryGB * 1024) }

    Write-Host "🔧 Resizing VM '$VmName'..." -ForegroundColor Cyan
    $null = Update-AzStackHCIVMVirtualMachine @updateParams

    # 4) Optionally start the VM again
    if ($wasRunning -and $Restart) {
        Write-Host "🔧 Starting VM '$VmName' again..." -ForegroundColor Cyan
        $null = Start-AzStackHCIVMVirtualMachine -Name $VmName -ResourceGroupName $ResourceGroupName
        Write-Host "✅ VM started" -ForegroundColor Green
    }
    elseif ($wasRunning) {
        Write-Host "ℹ️  VM '$VmName' was left stopped; pass -Restart to start it automatically" -ForegroundColor Yellow
    }

    # 5) Summary
    $newVcpu  = if ($VmVcpu -gt 0) { $VmVcpu } else { $oldVcpu }
    $newMemGb = if ($VmMemoryGB -gt 0) { $VmMemoryGB } else { [math]::Round($oldMemMb / 1024, 1) }
    Write-Host "📊 Summary: $oldVcpu vCPU / $([math]::Round($oldMemMb / 1024, 1)) GB -> $newVcpu vCPU / $newMemGb GB" -ForegroundColor Blue
    Write-Host "✅ VM '$VmName' resized" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
