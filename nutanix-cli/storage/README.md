# Nutanix CLI - Storage Management Scripts

This directory contains PowerShell scripts for managing Nutanix storage
containers via the Nutanix PowerShell SDK.

## Prerequisites

- Nutanix PowerShell SDK (`Nutanix.PowerShell.SDK`)
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Nutanix Prism Central or Prism Element access
- Storage administrator permissions

## Available Scripts

| Script | Description |
| --- | --- |
| `nutanix-cli-storage-containers.ps1` | Creates, modifies, monitors, and optimizes storage containers with support for compression, deduplication, erasure coding, and capacity quotas |

## Usage Examples

### Storage Container Operations

```powershell
# Create a container with compression and deduplication
.\nutanix-cli-storage-containers.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Create" `
    -ContainerName "Production-Storage" `
    -ClusterName "Prod-Cluster" `
    -EnableCompression `
    -EnableDeduplication `
    -ReplicationFactor 2

# List all containers, export to CSV
.\nutanix-cli-storage-containers.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "List" `
    -ClusterName "All-Clusters" `
    -OutputFormat "CSV" `
    -OutputPath "containers.csv"

# Monitor a specific container
.\nutanix-cli-storage-containers.ps1 `
    -PrismCentral "pc.domain.com" `
    -Operation "Monitor" `
    -ContainerName "Production-Storage" `
    -OutputFormat "JSON"
```
