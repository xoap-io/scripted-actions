<#
.SYNOPSIS
    Enable Azure Backup for a VM using a Recovery Services vault.

.DESCRIPTION
    This script enables Azure Backup protection for an Azure virtual machine using an existing
    Recovery Services vault and backup protection policy. It uses the following cmdlets:
    Get-AzRecoveryServicesVault - to locate the vault
    Get-AzRecoveryServicesBackupProtectionPolicy - to retrieve the backup policy
    Enable-AzRecoveryServicesBackupProtection - to enable backup on the VM

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group containing the VM.

.PARAMETER VmName
    The name of the Azure virtual machine for which backup will be enabled.

.PARAMETER VaultName
    The name of the Recovery Services vault to use for backup.

.PARAMETER VaultResourceGroup
    The resource group containing the Recovery Services vault.
    Defaults to the value of ResourceGroupName if not specified.

.PARAMETER PolicyName
    The name of the backup protection policy to apply.
    Default: DefaultPolicy

.EXAMPLE
    .\az-ps-enable-backup.ps1 -ResourceGroupName "MyRG" -VmName "MyVM" -VaultName "MyRecoveryVault"

    Enable backup using DefaultPolicy from a vault in the same resource group.

.EXAMPLE
    .\az-ps-enable-backup.ps1 -ResourceGroupName "AppRG" -VmName "AppVM" -VaultName "CentralVault" -VaultResourceGroup "BackupRG" -PolicyName "DailyBackupPolicy"

    Enable backup using a specific policy from a vault in a different resource group.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az.RecoveryServices PowerShell module

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.recoveryservices/enable-azrecoveryservicesbackupprotection

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

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure virtual machine for which backup will be enabled.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Recovery Services vault to use for backup.")]
    [ValidateNotNullOrEmpty()]
    [string]$VaultName,

    [Parameter(Mandatory = $false, HelpMessage = "The resource group containing the Recovery Services vault. Defaults to ResourceGroupName.")]
    [string]$VaultResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the backup protection policy to apply.")]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyName = 'DefaultPolicy'
)

$ErrorActionPreference = 'Stop'

# Default vault RG to the VM RG when not supplied
if (-not $VaultResourceGroup) {
    $VaultResourceGroup = $ResourceGroupName
}

try {
    Write-Host "🚀 Starting Azure Backup enable operation..." -ForegroundColor Green

    # Import module
    Write-Host "🔍 Loading Az.RecoveryServices module..." -ForegroundColor Cyan
    if (-not (Get-Module -Name Az.RecoveryServices -ListAvailable)) {
        throw "Az.RecoveryServices module is not installed. Install it with: Install-Module Az.RecoveryServices"
    }
    Import-Module Az.RecoveryServices -ErrorAction Stop

    # Get vault
    Write-Host "🔍 Retrieving Recovery Services vault '$VaultName'..." -ForegroundColor Cyan
    $vault = Get-AzRecoveryServicesVault -Name $VaultName -ResourceGroupName $VaultResourceGroup -ErrorAction Stop

    if (-not $vault) {
        throw "Recovery Services vault '$VaultName' not found in resource group '$VaultResourceGroup'."
    }

    Write-Host "✅ Vault found: $($vault.Name) (Location: $($vault.Location))" -ForegroundColor Green

    # Set vault context
    Set-AzRecoveryServicesVaultContext -Vault $vault

    # Get backup policy
    Write-Host "🔍 Retrieving backup policy '$PolicyName'..." -ForegroundColor Cyan
    $policy = Get-AzRecoveryServicesBackupProtectionPolicy -Name $PolicyName -ErrorAction Stop

    if (-not $policy) {
        throw "Backup policy '$PolicyName' not found in vault '$VaultName'."
    }

    Write-Host "✅ Policy found: $($policy.Name) (WorkloadType: $($policy.WorkloadType))" -ForegroundColor Green

    # Enable backup protection
    Write-Host "🔧 Enabling backup protection for VM '$VmName'..." -ForegroundColor Cyan

    $enableParams = @{
        ResourceGroupName = $ResourceGroupName
        Name              = $VmName
        Policy            = $policy
    }

    Enable-AzRecoveryServicesBackupProtection @enableParams

    Write-Host "✅ Azure Backup enabled successfully for VM '$VmName'." -ForegroundColor Green

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "  VM Name       : $VmName" -ForegroundColor White
    Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "  Vault Name    : $($vault.Name)" -ForegroundColor White
    Write-Host "  Policy Name   : $($policy.Name)" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "  - Trigger an on-demand backup with Backup-AzRecoveryServicesBackupItem" -ForegroundColor White
    Write-Host "  - Monitor backup jobs in the Azure Portal under the Recovery Services vault" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
