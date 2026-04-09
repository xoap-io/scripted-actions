# Storage Scripts

PowerShell scripts for managing Azure Storage accounts and file shares
using Azure CLI.

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)

## Available Scripts

| Script                                 | Description                                                                                  |
| -------------------------------------- | -------------------------------------------------------------------------------------------- |
| `az-cli-create-blob-container.ps1`     | Create a blob container in an existing storage account with configurable public access level |
| `az-cli-create-storage-account.ps1`    | Create an Azure Storage Account with configurable SKU, access tier, and security options     |
| `az-cli-create-share.ps1`              | Create an Azure Files share with configurable access tier, protocol, and quota               |
| `az-cli-delete-storage-account.ps1`    | Delete an Azure Storage Account                                                              |
| `az-cli-delete-share.ps1`              | Delete an Azure Files share                                                                  |
| `az-cli-download-blob.ps1`             | Download a blob from Azure Blob Storage to a local file path                                 |
| `az-cli-enable-storage-encryption.ps1` | Enable customer-managed key (CMK) encryption on a storage account using a Key Vault key      |
| `az-cli-set-blob-lifecycle-policy.ps1` | Set a lifecycle management policy to automatically tier and delete blobs by age              |
| `az-cli-upload-blob.ps1`               | Upload a local file to an Azure Blob Storage container                                       |

## Usage Examples

### Create a Storage Account

```powershell
.\az-cli-create-storage-account.ps1 `
    -Name "mystorageacct001" `
    -ResourceGroup "rg-storage" `
    -Location "eastus" `
    -AccountType "StorageV2"
```

### Create a File Share

```powershell
.\az-cli-create-share.ps1 `
    -Name "myfileshare" `
    -StorageAccount "mystorageacct001" `
    -AccessTier "Hot" `
    -EnabledProtocols "SMB" `
    -Quota 100 `
    -ResourceGroup "rg-storage"
```

### Delete a File Share

```powershell
.\az-cli-delete-share.ps1 `
    -Name "myfileshare" `
    -StorageAccount "mystorageacct001" `
    -ResourceGroup "rg-storage"
```

### Delete a Storage Account

```powershell
.\az-cli-delete-storage-account.ps1 `
    -Name "mystorageacct001" `
    -ResourceGroup "rg-storage"
```

### Create a Blob Container

```powershell
.\az-cli-create-blob-container.ps1 `
    -ResourceGroupName "rg-storage" `
    -StorageAccountName "mystorageacct001" `
    -ContainerName "mycontainer" `
    -PublicAccess "off"
```

### Upload a Blob

```powershell
.\az-cli-upload-blob.ps1 `
    -ResourceGroupName "rg-storage" `
    -StorageAccountName "mystorageacct001" `
    -ContainerName "mycontainer" `
    -LocalFilePath "C:\data\report.csv" `
    -BlobName "reports/2026/report.csv"
```

### Download a Blob

```powershell
.\az-cli-download-blob.ps1 `
    -ResourceGroupName "rg-storage" `
    -StorageAccountName "mystorageacct001" `
    -ContainerName "mycontainer" `
    -BlobName "reports/2026/report.csv" `
    -LocalFilePath "C:\downloads\report.csv"
```

### Set a Blob Lifecycle Policy

```powershell
.\az-cli-set-blob-lifecycle-policy.ps1 `
    -ResourceGroupName "rg-storage" `
    -StorageAccountName "mystorageacct001" `
    -CoolAfterDays 30 `
    -ArchiveAfterDays 90 `
    -DeleteAfterDays 365
```

### Enable Customer-Managed Key Encryption

```powershell
.\az-cli-enable-storage-encryption.ps1 `
    -ResourceGroupName "rg-storage" `
    -StorageAccountName "mystorageacct001" `
    -KeyVaultName "mykeyvault" `
    -KeyName "storage-cmk-key" `
    -EnableIdentity
```

## Notes

- Storage account names must be globally unique, lowercase, and between
  3 and 24 characters.
- File share access tiers: `Cool`, `Hot`, `Premium`, `TransactionOptimized`.
- File share protocols: `SMB` (default), `NFS` (requires Premium tier and
  a storage account with NFS 3.0 enabled).
- Deleting a storage account is irreversible and removes all data within it.
- CMK encryption requires the storage account's managed identity to have
  `get`, `wrapKey`, and `unwrapKey` permissions on the Key Vault key. Use
  `-EnableIdentity` to configure this automatically.
- Lifecycle policy day thresholds must be in ascending order:
  `CoolAfterDays` < `ArchiveAfterDays` < `DeleteAfterDays`.
