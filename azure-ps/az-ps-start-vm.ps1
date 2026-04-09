<#
.SYNOPSIS
    Start an Azure VM using the Az PowerShell module.

.DESCRIPTION
    This script starts an Azure virtual machine using the Start-AzVM cmdlet.
    It first retrieves the current power state of the VM and skips the operation if the
    VM is already running. Supports asynchronous start with the -NoWait switch.
    The underlying command used is:
    Start-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group containing the VM.

.PARAMETER VmName
    The name of the Azure virtual machine to start.

.PARAMETER NoWait
    Start the VM asynchronously without waiting for the operation to complete.

.EXAMPLE
    .\az-ps-start-vm.ps1 -ResourceGroupName "MyResourceGroup" -VmName "MyVM"

    Start a VM and wait for the operation to complete.

.EXAMPLE
    .\az-ps-start-vm.ps1 -ResourceGroupName "MyResourceGroup" -VmName "MyVM" -NoWait

    Start a VM asynchronously and return immediately.

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
    https://learn.microsoft.com/en-us/powershell/module/az.compute/start-azvm

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure virtual machine to start.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "Start the VM asynchronously without waiting for the operation to complete.")]
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting Azure VM operation..." -ForegroundColor Green

    # Import module
    Write-Host "🔍 Loading Az.Compute module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name Az.Compute -ListAvailable)) {
        throw "Az.Compute module is not installed. Install it with: Install-Module Az.Compute"
    }
    Import-Module Az.Compute -ErrorAction Stop

    # Get current VM state
    Write-Host "🔍 Checking current power state of '$VmName'..." -ForegroundColor Cyan
    $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName -Status -ErrorAction Stop

    if (-not $vm) {
        throw "VM '$VmName' not found in resource group '$ResourceGroupName'."
    }

    $powerState = ($vm.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus
    Write-Host "ℹ️  Current power state: $powerState" -ForegroundColor Yellow

    if ($powerState -eq 'VM running') {
        Write-Host "⚠️  VM '$VmName' is already running. No action taken." -ForegroundColor Yellow
        return
    }

    # Build start params
    $startParams = @{
        ResourceGroupName = $ResourceGroupName
        Name              = $VmName
    }
    if ($NoWait) { $startParams.NoWait = $true }

    Write-Host "🔧 Starting VM '$VmName'..." -ForegroundColor Cyan
    $result = Start-AzVM @startParams

    if ($NoWait) {
        Write-Host "✅ Start operation for VM '$VmName' submitted asynchronously." -ForegroundColor Green
    }
    else {
        if ($result.Status -eq 'Succeeded') {
            Write-Host "✅ VM '$VmName' started successfully." -ForegroundColor Green
        }
        else {
            throw "Start operation completed with status: $($result.Status). Error: $($result.Error)"
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
