<#
.SYNOPSIS
    Enable customer-managed key (CMK) encryption on an Azure Storage Account using the Azure CLI.

.DESCRIPTION
    This script enables customer-managed key (CMK) encryption on an Azure Storage Account
    by linking it to an Azure Key Vault key using the Azure CLI.
    Optionally enables a system-assigned managed identity on the storage account if required
    for Key Vault access.
    The script uses the following Azure CLI command:
    az storage account update --encryption-key-source Microsoft.Keyvault

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group containing the Storage Account.

.PARAMETER StorageAccountName
    Defines the name of the Azure Storage Account to enable CMK encryption on.

.PARAMETER KeyVaultName
    Defines the name of the Azure Key Vault containing the encryption key.

.PARAMETER KeyName
    Defines the name of the key in the Key Vault to use for encryption.

.PARAMETER KeyVaultResourceGroup
    Defines the name of the Resource Group containing the Key Vault.
    Defaults to ResourceGroupName if not specified.

.PARAMETER EnableIdentity
    If specified, enables a system-assigned managed identity on the storage account
    before applying CMK encryption (required if no identity is already configured).

.EXAMPLE
    .\az-cli-enable-storage-encryption.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -KeyVaultName "mykeyvault" -KeyName "storage-cmk-key" -EnableIdentity

.EXAMPLE
    .\az-cli-enable-storage-encryption.ps1 -ResourceGroupName "rg-storage" -StorageAccountName "mystorageacct001" -KeyVaultName "shared-keyvault" -KeyName "storage-cmk-key" -KeyVaultResourceGroup "rg-security"

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
    https://learn.microsoft.com/en-us/cli/azure/storage/account

.COMPONENT
    Azure CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group containing the Storage Account")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Storage Account to enable CMK encryption on")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Key Vault containing the encryption key")]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultName,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the key in the Key Vault to use for encryption")]
    [ValidateNotNullOrEmpty()]
    [string]$KeyName,

    [Parameter(Mandatory = $false, HelpMessage = "The Resource Group containing the Key Vault (defaults to ResourceGroupName)")]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Enable system-assigned managed identity on the storage account if not already configured")]
    [switch]$EnableIdentity
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "🚀 Enabling customer-managed key (CMK) encryption on storage account '$StorageAccountName'..." -ForegroundColor Green

    # Verify Azure CLI is available
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not in PATH. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    }

    # Default Key Vault resource group to storage resource group
    if (-not $KeyVaultResourceGroup) {
        $KeyVaultResourceGroup = $ResourceGroupName
        Write-Host "ℹ️  KeyVaultResourceGroup not specified. Using: $KeyVaultResourceGroup" -ForegroundColor Yellow
    }

    # Enable system-assigned managed identity if requested
    if ($EnableIdentity) {
        Write-Host "🔧 Enabling system-assigned managed identity on storage account '$StorageAccountName'..." -ForegroundColor Cyan
        $identityJson = az storage account update `
            --resource-group $ResourceGroupName `
            --name $StorageAccountName `
            --assign-identity `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to enable managed identity on storage account."
        }

        $identity = $identityJson | ConvertFrom-Json
        $principalId = $identity.identity.principalId

        Write-Host "✅ Managed identity enabled. Principal ID: $principalId" -ForegroundColor Green

        # Retrieve Key Vault URI
        Write-Host "🔍 Retrieving Key Vault URI..." -ForegroundColor Cyan
        $kvJson = az keyvault show `
            --name $KeyVaultName `
            --resource-group $KeyVaultResourceGroup `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve Key Vault details for '$KeyVaultName'."
        }

        $kv = $kvJson | ConvertFrom-Json
        $kvUri = $kv.properties.vaultUri

        Write-Host "🔧 Granting storage identity access to Key Vault '$KeyVaultName'..." -ForegroundColor Cyan
        az keyvault set-policy `
            --name $KeyVaultName `
            --resource-group $KeyVaultResourceGroup `
            --object-id $principalId `
            --key-permissions get unwrapKey wrapKey | Out-Null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set Key Vault access policy for the storage managed identity."
        }

        Write-Host "✅ Key Vault access policy set." -ForegroundColor Green
    }
    else {
        # Retrieve Key Vault URI without modifying identity
        Write-Host "🔍 Retrieving Key Vault URI..." -ForegroundColor Cyan
        $kvJson = az keyvault show `
            --name $KeyVaultName `
            --resource-group $KeyVaultResourceGroup `
            --output json

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve Key Vault details for '$KeyVaultName'."
        }

        $kv = $kvJson | ConvertFrom-Json
        $kvUri = $kv.properties.vaultUri
    }

    # Enable CMK encryption on the storage account
    Write-Host "🔧 Enabling CMK encryption using Key Vault key '$KeyName'..." -ForegroundColor Cyan
    $updateJson = az storage account update `
        --resource-group $ResourceGroupName `
        --name $StorageAccountName `
        --encryption-key-source Microsoft.Keyvault `
        --encryption-key-vault $kvUri `
        --encryption-key-name $KeyName `
        --output json

    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI storage account update command failed with exit code $LASTEXITCODE"
    }

    $storageAccount = $updateJson | ConvertFrom-Json

    Write-Host "`n✅ CMK encryption enabled on storage account '$StorageAccountName'." -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Blue
    Write-Host "   StorageAccount:  $StorageAccountName" -ForegroundColor White
    Write-Host "   KeyVault:        $KeyVaultName" -ForegroundColor White
    Write-Host "   KeyName:         $KeyName" -ForegroundColor White
    Write-Host "   KeySource:       $($storageAccount.encryption.keySource)" -ForegroundColor White
    Write-Host "   ProvisioningState: $($storageAccount.provisioningState)" -ForegroundColor White
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
