<#
.SYNOPSIS
    Stop and deallocate an Azure VM using the Az PowerShell module.

.DESCRIPTION
    This script stops and deallocates an Azure virtual machine using the Stop-AzVM cmdlet.
    It first displays the current power state of the VM. By default the VM is fully deallocated
    to avoid compute charges. Use -SkipDeallocate to keep the VM provisioned (StayProvisioned).
    The -Force switch skips the confirmation prompt.
    The underlying command used is:
    Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName [-StayProvisioned] [-Force]

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group containing the VM.

.PARAMETER VmName
    The name of the Azure virtual machine to stop.

.PARAMETER Force
    Skip the confirmation prompt and stop the VM immediately.

.PARAMETER SkipDeallocate
    Stop the VM without deallocating it (StayProvisioned). Compute charges continue to apply.

.PARAMETER NoWait
    Stop the VM asynchronously without waiting for the operation to complete.

.EXAMPLE
    .\az-ps-stop-vm.ps1 -ResourceGroupName "MyResourceGroup" -VmName "MyVM" -Force

    Stop and deallocate a VM immediately without confirmation.

.EXAMPLE
    .\az-ps-stop-vm.ps1 -ResourceGroupName "MyResourceGroup" -VmName "MyVM" -SkipDeallocate

    Stop a VM but keep it provisioned (powered off, not deallocated).

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
    https://learn.microsoft.com/en-us/powershell/module/az.compute/stop-azvm

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure virtual machine to stop.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "Skip the confirmation prompt and stop the VM immediately.")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Stop the VM without deallocating it (StayProvisioned). Compute charges continue to apply.")]
    [switch]$SkipDeallocate,

    [Parameter(Mandatory = $false, HelpMessage = "Stop the VM asynchronously without waiting for the operation to complete.")]
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting Azure VM stop operation..." -ForegroundColor Green

    # Import module
    Write-Host "🔍 Loading Az.Compute module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name Az.Compute -ListAvailable)) {
        throw "Az.Compute module is not installed. Install it with: Install-Module Az.Compute"
    }
    Import-Module Az.Compute -ErrorAction Stop

    # Show current VM state
    Write-Host "🔍 Checking current power state of '$VmName'..." -ForegroundColor Cyan
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status -ErrorAction Stop

    if (-not $vm) {
        throw "VM '$VmName' not found in resource group '$ResourceGroupName'."
    }

    $powerState = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus
    Write-Host "ℹ️  Current power state: $powerState" -ForegroundColor Yellow

    if ($powerState -eq 'VM deallocated') {
        Write-Host "⚠️  VM '$VmName' is already deallocated. No action taken." -ForegroundColor Yellow
        return
    }

    # Confirmation
    if (-not $Force) {
        $action = if ($SkipDeallocate) { 'stop (StayProvisioned)' } else { 'stop and deallocate' }
        $confirm = Read-Host "Proceed to $action VM '$VmName'? (y/N)"
        if ($confirm -notmatch '^[Yy]$') {
            Write-Host "⚠️  Operation cancelled by user." -ForegroundColor Yellow
            return
        }
    }

    # Build stop params
    $stopParams = @{
        ResourceGroupName = $ResourceGroupName
        Name              = $VmName
        Force             = $true
    }
    if ($SkipDeallocate) { $stopParams.StayProvisioned = $true }
    if ($NoWait) { $stopParams.NoWait = $true }

    $modeLabel = if ($SkipDeallocate) { 'stopping (StayProvisioned)' } else { 'stopping and deallocating' }
    Write-Host "🔧 $modeLabel VM '$VmName'..." -ForegroundColor Cyan
    $result = Stop-AzVM @stopParams

    if ($NoWait) {
        Write-Host "✅ Stop operation for VM '$VmName' submitted asynchronously." -ForegroundColor Green
    }
    else {
        if ($result.Status -eq 'Succeeded') {
            Write-Host "✅ VM '$VmName' stopped successfully." -ForegroundColor Green
        }
        else {
            throw "Stop operation completed with status: $($result.Status). Error: $($result.Error)"
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
