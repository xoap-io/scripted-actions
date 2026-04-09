<#
.SYNOPSIS
    Start an Azure Virtual Machine using the Azure CLI.

.DESCRIPTION
    This script starts an Azure Virtual Machine using the Azure CLI.
    The script uses the following Azure CLI command:
    az vm start --resource-group $ResourceGroupName --name $VmName

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the VM.

.PARAMETER VmName
    Defines the name of the Azure Virtual Machine to start.

.PARAMETER NoWait
    If specified, the script does not wait for the start operation to complete.

.EXAMPLE
    .\az-cli-start-vm.ps1 -ResourceGroupName "rg-vms" -VmName "vm-web-prod-01"

.EXAMPLE
    .\az-cli-start-vm.ps1 -ResourceGroupName "rg-vms" -VmName "vm-web-prod-01" -NoWait

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Machine to start")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, do not wait for the start operation to complete")]
    [switch]$NoWait
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Starting Azure VM '$VmName' in resource group '$ResourceGroupName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Build start command arguments
    $startArgs = @(
        'vm', 'start',
        '--resource-group', $ResourceGroupName,
        '--name', $VmName
    )

    if ($NoWait) {
        $startArgs += '--no-wait'
        Write-Host "ℹ️  No-wait mode enabled. The script will not wait for the VM to fully start." -ForegroundColor Yellow
    }

    # Start the VM
    Write-Host "🔧 Sending start command to VM '$VmName'..." -ForegroundColor Cyan
    az @startArgs

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code $LASTEXITCODE"
    }

    if (-not $NoWait) {
        # Get and display VM state after start
        Write-Host "🔍 Retrieving VM state..." -ForegroundColor Cyan
        $vmJson = az vm show `
            --resource-group $ResourceGroupName `
            --name $VmName `
            --show-details `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve VM state after start"
        }

        $vm = $vmJson | ConvertFrom-Json

        Write-Host "`n✅ VM '$VmName' started successfully." -ForegroundColor Green
        Write-Host "📊 Summary:" -ForegroundColor Blue
        Write-Host "   Name:          $($vm.name)" -ForegroundColor White
        Write-Host "   Resource Group: $($vm.resourceGroup)" -ForegroundColor White
        Write-Host "   Location:      $($vm.location)" -ForegroundColor White
        Write-Host "   Power State:   $($vm.powerState)" -ForegroundColor White
        Write-Host "   Private IP:    $($vm.privateIps)" -ForegroundColor White
        Write-Host "   Public IP:     $($vm.publicIps)" -ForegroundColor White
    }
    else {
        Write-Host "✅ Start command sent to VM '$VmName'. The VM is starting in the background." -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
