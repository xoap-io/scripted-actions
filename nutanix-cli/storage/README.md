# Nutanix CLI - Storage Management Scripts

This directory contains PowerShell scripts for managing Nutanix storage using Nutanix REST API.

## Prerequisites

- Nutanix Prism Central or Prism Element access
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Nutanix REST API credentials
- Storage administrator permissions

## Available Scripts

Scripts for managing Nutanix storage components:

### Storage Containers

- Create storage containers
- Configure compression/deduplication
- Manage container quotas
- Container performance tuning

### Volume Groups

- Create volume groups
- Attach/detach disks
- iSCSI configuration
- Volume snapshots

### Protection Domains

- Create protection domains
- Configure replication
- Snapshot schedules
- Recovery point objectives (RPO)

## Usage Examples

### Create Storage Container

```powershell
# Storage container creation
$body = @{
    "name" = "MyContainer"
    "storage_pool_uuid" = "pool-uuid"
    "compression_enabled" = $true
    "on_disk_dedup" = "POST_PROCESS"
} | ConvertTo-Json

Invoke-RestMethod `
    -Uri "https://${prismElement}:9440/PrismGateway/services/rest/v2.0/storage_containers" `
    -Method POST `
    -Headers $headers `
    -Body $body `
    -SkipCertificateCheck
```

### Create Volume Group

```powershell
# Volume group creation
$volumeGroupSpec = @{
    "spec" = @{
        "name" = "MyVolumeGroup"
        "resources" = @{
            "flash_mode_enabled" = $false
            "disk_list" = @(
                @{
                    "vmdisk_size_mib" = 10240
                    "storage_container_uuid" = "container-uuid"
                }
            )
        }
    }
    "metadata" = @{
        "kind" = "volume_group"
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
    -Uri "https://${prismCentral}:9440/api/nutanix/v3/volume_groups" `
    -Method POST `
    -Headers $headers `
    -Body $volumeGroupSpec `
    -SkipCertificateCheck
```

## Nutanix Storage Best Practices

- **Capacity Planning**:

  - Monitor storage utilization
  - Plan for deduplication/compression ratios
  - Account for replication overhead
  - Reserve capacity for snapshots

- **Performance**:

  - Use SSDs for hot data
  - Enable compression for cold data
  - Optimize deduplication settings
  - Monitor IOPS and latency

- **Data Protection**:

  - Configure protection domains
  - Set appropriate RPO/RTO
  - Test restore procedures
  - Use snapshots wisely
  - Implement replication

- **Optimization**:
  - Enable inline compression
  - Use post-process deduplication
  - Implement erasure coding
  - Configure tiering policies

## Storage Features

### Compression

- Inline compression
- Post-process compression
- Configurable per container
- Reduces storage footprint

### Deduplication

- Post-process deduplication
- Fingerprint-based
- Operates on 4KB blocks
- Significant space savings

### Erasure Coding

- RF2 or RF3 equivalent
- Better space efficiency than replication
- Automatic healing
- Performance considerations

### Tiering

- Hot data on SSD
- Cold data on HDD
- Automatic tier management
- Configurable policies

## Error Handling

Scripts include:

- Storage pool validation
- Capacity checks
- UUID verification
- API response validation
- Comprehensive error messages

## Related Documentation

- [Nutanix Storage Documentation](https://portal.nutanix.com/page/documents)
- [Storage Best Practices](https://www.nutanix.com/go/storage-best-practices)
- [Nutanix Storage API](https://www.nutanix.dev/)

## Support

For issues or questions, please refer to the main repository documentation.
