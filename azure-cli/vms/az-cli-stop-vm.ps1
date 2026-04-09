<#
.SYNOPSIS
    Stop and deallocate an Azure Virtual Machine using the Azure CLI.

.DESCRIPTION
    This script stops and deallocates an Azure Virtual Machine using the Azure CLI.
    Deallocating a VM stops billing for compute resources. Use the -SkipDeallocate
    switch to simply power off the VM without deallocating it (billing continues).
    The script uses the following Azure CLI commands:
    az vm show --show-details (to get current state)
    az vm deallocate --resource-group $ResourceGroupName --name $VmName
    az vm stop --resource-group $ResourceGroupName --name $VmName (when -SkipDeallocate)

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the VM.

.PARAMETER VmName
    Defines the name of the Azure Virtual Machine to stop.

.PARAMETER SkipDeallocate
    If specified, the VM is powered off without deallocating it. Billing continues.

.PARAMETER NoWait
    If specified, the script does not wait for the stop operation to complete.

.PARAMETER Force
    If specified, skips the confirmation prompt before stopping the VM.

.EXAMPLE
    .\az-cli-stop-vm.ps1 -ResourceGroupName "rg-vms" -VmName "vm-web-prod-01" -Force

.EXAMPLE
    .\az-cli-stop-vm.ps1 -ResourceGroupName "rg-vms" -VmName "vm-web-prod-01" -SkipDeallocate -NoWait

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the VM")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Machine to stop")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "Power off without deallocating (billing continues)")]
    [switch]$SkipDeallocate,

    [Parameter(Mandatory = $false, HelpMessage = "Do not wait for the stop operation to complete")]
    [switch]$NoWait,

    [Parameter(Mandatory = $false, HelpMessage = "Skip the confirmation prompt before stopping the VM")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Preparing to stop Azure VM '$VmName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Get current VM state before stopping
    Write-Host "🔍 Retrieving current VM state..." -ForegroundColor Cyan
    $vmJson = az vm show `
        --resource-group $ResourceGroupName `
        --name $VmName `
        --show-details `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve VM state. Verify the VM name and resource group are correct."
    }

    $vm = $vmJson | ConvertFrom-Json

    Write-Host "ℹ️  Current VM state: $($vm.powerState)" -ForegroundColor Yellow
    Write-Host "   Name:          $($vm.name)" -ForegroundColor White
    Write-Host "   Resource Group: $($vm.resourceGroup)" -ForegroundColor White
    Write-Host "   Location:      $($vm.location)" -ForegroundColor White

    # Prompt for confirmation unless -Force is specified
    if (-not $Force) {
        $action = if ($SkipDeallocate) { "power off (without deallocating)" } else { "stop and deallocate" }
        $confirmation = Read-Host "`nAre you sure you want to $action VM '$VmName'? (yes/no)"
        if ($confirmation -notmatch '^(yes|y)$') {
            Write-Host "⚠️  Operation cancelled by user." -ForegroundColor Yellow
            return
        }
    }

    # Build stop/deallocate command arguments
    if ($SkipDeallocate) {
        Write-Host "`n🔧 Powering off VM '$VmName' (without deallocating)..." -ForegroundColor Cyan
        $stopArgs = @(
            'vm', 'stop',
            '--resource-group', $ResourceGroupName,
            '--name', $VmName
        )
    }
    else {
        Write-Host "`n🔧 Stopping and deallocating VM '$VmName'..." -ForegroundColor Cyan
        $stopArgs = @(
            'vm', 'deallocate',
            '--resource-group', $ResourceGroupName,
            '--name', $VmName
        )
    }

    if ($NoWait) {
        $stopArgs += '--no-wait'
        Write-Host "ℹ️  No-wait mode enabled. The script will not wait for the VM to fully stop." -ForegroundColor Yellow
    }

    az @stopArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code $LASTEXITCODE"
    }

    if (-not $NoWait) {
        $action = if ($SkipDeallocate) { "powered off" } else { "stopped and deallocated" }
        Write-Host "`n✅ VM '$VmName' has been $action successfully." -ForegroundColor Green

        if (-not $SkipDeallocate) {
            Write-Host "💡 Next Steps:" -ForegroundColor Yellow
            Write-Host "   - Compute billing has stopped for this VM." -ForegroundColor White
            Write-Host "   - Storage billing for OS and data disks continues." -ForegroundColor White
            Write-Host "   - Use az-cli-start-vm.ps1 to start the VM again." -ForegroundColor White
        }
        else {
            Write-Host "⚠️  VM is powered off but still allocated. Compute billing continues." -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "✅ Stop command sent to VM '$VmName'. The VM is stopping in the background." -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
