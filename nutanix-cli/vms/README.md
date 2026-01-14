# Nutanix CLI - VM Management Scripts

This directory contains PowerShell scripts for managing Nutanix virtual machines using Nutanix REST API.

## Prerequisites

- Nutanix Prism Central or Prism Element access
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Nutanix REST API credentials
- VM management permissions

## Available Scripts

Scripts for managing Nutanix AHV virtual machines:

### VM Lifecycle

- Create VMs from templates
- Power on/off VMs
- Clone VMs
- Delete VMs
- VM migration

### VM Configuration

- CPU/memory adjustments
- Disk management
- Network configuration
- VM guest tools

### Bulk Operations

- Batch VM creation
- Mass power operations
- Bulk configuration updates

## Usage Examples

### Create VM

```powershell
# VM creation spec
$vmSpec = @{
    "spec" = @{
        "name" = "MyVM"
        "resources" = @{
            "power_state" = "ON"
            "num_vcpus_per_socket" = 2
            "num_sockets" = 1
            "memory_size_mib" = 4096
            "disk_list" = @(
                @{
                    "disk_size_mib" = 51200
                    "device_properties" = @{
                        "device_type" = "DISK"
                        "disk_address" = @{
                            "device_index" = 0
                            "adapter_type" = "SCSI"
                        }
                    }
                    "data_source_reference" = @{
                        "kind" = "image"
                        "uuid" = "image-uuid"
                    }
                }
            )
            "nic_list" = @(
                @{
                    "subnet_reference" = @{
                        "kind" = "subnet"
                        "uuid" = "subnet-uuid"
                    }
                }
            )
        }
    }
    "metadata" = @{
        "kind" = "vm"
    }
} | ConvertTo-Json -Depth 10

$vm = Invoke-RestMethod `
    -Uri "https://${prismCentral}:9440/api/nutanix/v3/vms" `
    -Method POST `
    -Headers $headers `
    -Body $vmSpec `
    -SkipCertificateCheck
```

### Power Operations

```powershell
# Get VM
$vm = Invoke-RestMethod `
    -Uri "https://${prismCentral}:9440/api/nutanix/v3/vms/list" `
    -Method POST `
    -Headers $headers `
    -Body (@{"filter" = "vm_name==MyVM"} | ConvertTo-Json) `
    -SkipCertificateCheck

# Power on VM
$powerOnSpec = $vm.entities[0]
$powerOnSpec.spec.resources.power_state = "ON"

Invoke-RestMethod `
    -Uri "https://${prismCentral}:9440/api/nutanix/v3/vms/$($vm.entities[0].metadata.uuid)" `
    -Method PUT `
    -Headers $headers `
    -Body ($powerOnSpec | ConvertTo-Json -Depth 10) `
    -SkipCertificateCheck
```

### Clone VM

```powershell
# Clone VM
$cloneSpec = @{
    "spec_list" = @(
        @{
            "name" = "MyVM-Clone"
            "override_network_config" = $true
        }
    )
} | ConvertTo-Json -Depth 10

Invoke-RestMethod `
    -Uri "https://${prismCentral}:9440/api/nutanix/v3/vms/$vmUuid/clone" `
    -Method POST `
    -Headers $headers `
    -Body $cloneSpec `
    -SkipCertificateCheck
```

## Nutanix VM Best Practices

- **Resource Allocation**:

  - Right-size CPU and memory
  - Use hot-add for flexibility
  - Monitor resource utilization
  - Implement resource limits

- **Storage**:

  - Use appropriate storage containers
  - Enable compression for OS disks
  - Separate OS and data disks
  - Regular snapshot management

- **Networking**:

  - Use VLANs for segmentation
  - Configure proper security policies
  - Implement network redundancy
  - Monitor network performance

- **High Availability**:
  - Enable HA for critical VMs
  - Distribute VMs across hosts
  - Use affinity policies appropriately
  - Regular DR testing

## AHV Features

### VM Management

- Acropolis Dynamic Scheduling (ADS)
- Live migration
- High availability
- Affinity policies

### Guest Tools

- Nutanix Guest Tools (NGT)
- Self-service file restore
- Application consistent snapshots
- Performance monitoring

### Integration

- Cloud-init support
- Sysprep integration
- Custom script execution
- Guest customization

## Error Handling

Scripts include:

- Connection validation
- Resource availability checks
- UUID verification
- API response validation
- Power state validation
- Comprehensive error messages

## Related Documentation

- [Nutanix AHV Documentation](https://portal.nutanix.com/page/documents/details?targetId=AHV-Admin-Guide)
- [Nutanix VM API](https://www.nutanix.dev/api_references/prism-central-v3/#/b3A6MjE5NTE3OA-create-a-vm)
- [AHV Best Practices](https://www.nutanix.com/go/ahv-best-practices)

## Support

For issues or questions, please refer to the main repository documentation.
