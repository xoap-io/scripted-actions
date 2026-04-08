# Storage Scripts

PowerShell scripts for managing Azure Storage accounts and file shares
using Azure CLI.

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)

## Available Scripts

| Script | Description |
| --- | --- |
| `az-cli-create-storage-account.ps1` | Create an Azure Storage Account with configurable SKU, access tier, and security options |
| `az-cli-create-share.ps1` | Create an Azure Files share with configurable access tier, protocol, and quota |
| `az-cli-delete-storage-account.ps1` | Delete an Azure Storage Account |
| `az-cli-delete-share.ps1` | Delete an Azure Files share |

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

## Notes

- Storage account names must be globally unique, lowercase, and between
  3 and 24 characters.
- File share access tiers: `Cool`, `Hot`, `Premium`, `TransactionOptimized`.
- File share protocols: `SMB` (default), `NFS` (requires Premium tier and
  a storage account with NFS 3.0 enabled).
- Deleting a storage account is irreversible and removes all data within it.
