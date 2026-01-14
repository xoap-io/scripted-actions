# Azure CLI - Storage Scripts

This directory contains PowerShell scripts for managing Azure Storage services using Azure CLI.

## Prerequisites

- Azure CLI 2.50+ installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions
- Azure CLI logged in (`az login`)
- Storage Account Contributor role or equivalent

## Available Scripts

### Storage Account Management

- Create and configure storage accounts
- List storage accounts
- Update storage account properties
- Delete storage accounts
- Manage access keys

### Blob Storage

- Container management (create, list, delete)
- Blob upload and download
- Blob copy operations
- Access tier management (Hot, Cool, Archive)
- Lifecycle management policies

### File Shares (Azure Files)

- File share creation and management
- File upload and download
- Snapshot management
- Quota configuration

### Queue Storage

- Queue creation and deletion
- Message operations
- Queue properties

### Table Storage

- Table creation and management
- Entity operations

## Usage Examples

### Create Storage Account

```powershell
# Create storage account
az storage account create `
    --name mystorageaccount `
    --resource-group myResourceGroup `
    --location eastus `
    --sku Standard_LRS `
    --kind StorageV2 `
    --access-tier Hot `
    --https-only true `
    --min-tls-version TLS1_2
```

### Blob Operations

```powershell
# Get storage account key
$key = az storage account keys list `
    --resource-group myResourceGroup `
    --account-name mystorageaccount `
    --query '[0].value' -o tsv

# Create container
az storage container create `
    --account-name mystorageaccount `
    --account-key $key `
    --name mycontainer `
    --public-access off

# Upload blob
az storage blob upload `
    --account-name mystorageaccount `
    --account-key $key `
    --container-name mycontainer `
    --name myblob.txt `
    --file ./localfile.txt `
    --tier Hot

# Download blob
az storage blob download `
    --account-name mystorageaccount `
    --account-key $key `
    --container-name mycontainer `
    --name myblob.txt `
    --file ./downloaded.txt

# List blobs
az storage blob list `
    --account-name mystorageaccount `
    --account-key $key `
    --container-name mycontainer `
    --output table
```

### Azure Files

```powershell
# Create file share
az storage share create `
    --account-name mystorageaccount `
    --account-key $key `
    --name myfileshare `
    --quota 100

# Upload file
az storage file upload `
    --account-name mystorageaccount `
    --account-key $key `
    --share-name myfileshare `
    --source ./document.pdf `
    --path documents/document.pdf
```

### Configure Lifecycle Management

```powershell
# Create lifecycle policy JSON
$policy = @{
    rules = @(
        @{
            name = "MoveToArchive"
            enabled = $true
            type = "Lifecycle"
            definition = @{
                actions = @{
                    baseBlob = @{
                        tierToArchive = @{
                            daysAfterModificationGreaterThan = 90
                        }
                        delete = @{
                            daysAfterModificationGreaterThan = 365
                        }
                    }
                }
                filters = @{
                    blobTypes = @("blockBlob")
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

# Apply policy
az storage account management-policy create `
    --account-name mystorageaccount `
    --resource-group myResourceGroup `
    --policy $policy
```

## Azure Storage Best Practices

- **Security**:

  - Enable firewall and virtual networks
  - Use Shared Access Signatures (SAS) with minimal permissions
  - Enable Azure AD authentication
  - Require secure transfer (HTTPS only)
  - Use Private Endpoints for sensitive data
  - Enable soft delete for blobs and containers

- **Performance**:

  - Choose appropriate access tier (Hot/Cool/Archive)
  - Use CDN for frequently accessed content
  - Enable static website hosting for web content
  - Consider Premium storage for high-IOPS workloads

- **Cost Optimization**:

  - Implement lifecycle management policies
  - Move infrequently accessed data to Cool or Archive tier
  - Delete unused snapshots and old versions
  - Monitor storage analytics
  - Use Azure Storage Reserved Capacity

- **Data Management**:
  - Enable versioning for critical data
  - Implement blob change feed for auditing
  - Use blob inventory for large-scale analysis
  - Configure geo-redundancy based on requirements

## Storage Redundancy Options

- **LRS** (Locally Redundant): 3 copies in single datacenter
- **ZRS** (Zone Redundant): 3 copies across availability zones
- **GRS** (Geo Redundant): LRS + async replication to secondary region
- **GZRS** (Geo-Zone Redundant): ZRS + async replication to secondary region
- **RA-GRS/RA-GZRS**: Read access to secondary region

## Access Tiers

- **Hot**: Frequently accessed data, highest storage cost, lowest access cost
- **Cool**: Infrequently accessed, stored for 30+ days
- **Archive**: Rarely accessed, stored for 180+ days, lowest storage cost

## Error Handling

Scripts include:

- Storage account name validation (globally unique, lowercase, 3-24 chars)
- Container/blob name validation
- Permission checks
- Quota validation
- Comprehensive error messages

## Related Documentation

- [Azure Storage Documentation](https://docs.microsoft.com/azure/storage/)
- [Azure Blob Storage Documentation](https://docs.microsoft.com/azure/storage/blobs/)
- [Azure Files Documentation](https://docs.microsoft.com/azure/storage/files/)
- [Azure CLI Storage Commands](https://docs.microsoft.com/cli/azure/storage)
- [Storage Best Practices](https://docs.microsoft.com/azure/storage/blobs/storage-blob-best-practices)

## Support

For issues or questions, please refer to the main repository documentation.
