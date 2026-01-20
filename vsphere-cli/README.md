# vSphere CLI Scripts Collection

This collection provides comprehensive PowerShell scripts for managing VMware vSphere 9.0 infrastructure using PowerCLI. All scripts include automatic PowerCLI installation and verification, following the established patterns of the scripted-actions repository.

## 📁 Directory Structure

```
vsphere-cli/
├── vms/                    # Virtual Machine operations
├── infrastructure/        # Infrastructure management
├── monitoring/            # Performance monitoring and reporting
└── README.md              # This documentation
```

## 🚀 Core VM Operations (`vms/`)

### VM Provisioning & Management

1. **`vsphere-cli-create-vm-from-template.ps1`** - Create new VMs from templates

   - Template-based VM creation with guest OS customization
   - Resource allocation (CPU, memory) override
   - Network configuration and datastore placement
   - PowerCLI auto-installation and vCenter connection management

2. **`vsphere-cli-clone-vm.ps1`** - Clone VMs and templates

   - Full clones and linked clones support
   - Bulk cloning with auto-generated naming
   - Resource modification during cloning
   - Asynchronous operations support

3. **`vsphere-cli-vm-power-operations.ps1`** - Advanced VM power management

   - Start, stop, restart, suspend, reset operations
   - Graceful vs. hard power operations with VMware Tools integration
   - Sequential startup with configurable delays
   - Bulk operations with cluster/resource pool targeting
   - Auto-snapshot creation before power operations
   - Comprehensive status reporting with uptime tracking

4. **`vsphere-cli-snapshot-vm.ps1`** - Snapshot management

   - Create, list, revert, delete snapshots
   - Snapshot cleanup with retention policies
   - Memory and quiesce options
   - Batch operations across multiple VMs

5. **`vsphere-cli-migrate-vm.ps1`** - VM migration operations

   - vMotion (compute migration) between hosts
   - Storage vMotion between datastores
   - Migration validation and compatibility checking
   - Bulk migration with safety checks

6. **`vsphere-cli-windows-updates.ps1`** - Windows Update management
   - Automated Windows update scanning and installation
   - Multiple update categories (Security, Critical, Important)
   - PSWindowsUpdate module auto-installation
   - Reboot management with completion tracking
   - Update history reporting and compliance checking
   - Concurrent VM processing with safety controls

## 🏗️ Infrastructure Management (`infrastructure/`)

### Inventory & Reporting

1. **`vsphere-cli-describe-inventory.ps1`** - Comprehensive infrastructure reporting
   - Datacenter, cluster, host, VM inventory
   - Datastore and network information
   - Resource utilization summaries
   - Multiple output formats (Console, CSV, HTML, JSON)
   - Performance metrics integration

## 📊 Monitoring & Performance (`monitoring/`)

### Performance Analysis

1. **`vsphere-cli-get-vm-performance.ps1`** - VM performance monitoring
   - CPU, memory, disk, network metrics collection
   - Real-time and historical data analysis
   - Alert thresholds with customizable limits
   - Continuous monitoring mode
   - Export capabilities (CSV, JSON)

## 🔧 Key Features

### PowerCLI Integration

- **Automatic Installation**: All scripts check for and install PowerCLI if missing
- **Version Compatibility**: Supports PowerCLI 13.x+ and vSphere 7.0+
- **Connection Management**: Automatic vCenter connection with credential caching
- **Error Handling**: Comprehensive error handling with meaningful messages

### Parameter Validation

- **Resource IDs**: Validation for VM names, datastore names, cluster names
- **Network Configuration**: Port group and VLAN validation
- **Resource Limits**: CPU core and memory limits validation
- **PowerShell Best Practices**: CmdletBinding with parameter sets

### Operational Safety

- **Confirmation Prompts**: Force parameter to bypass confirmations
- **Pre-flight Checks**: Validation of all required vSphere objects
- **Idempotency**: Safe to run multiple times without side effects
- **Cleanup**: Automatic vCenter disconnection in finally blocks

## 📋 Prerequisites

### Software Requirements

- **PowerShell 5.1** or later (Windows PowerShell or PowerShell Core)
- **VMware PowerCLI 13.x** or later (auto-installed if missing)
- **vSphere 7.0** or later (tested with vSphere 9.0)

### vSphere Permissions

Scripts require appropriate vSphere permissions based on operations:

- **VM Operations**: Virtual machine power operations, configuration changes
- **Resource Management**: Datastore access, resource pool management
- **Infrastructure**: Read access to datacenter, cluster, host inventory
- **Performance**: Statistics read access for monitoring operations

### Network Requirements

- **vCenter Connectivity**: Network access to vCenter Server (port 443)
- **DNS Resolution**: Proper DNS resolution for vCenter FQDN
- **Firewall**: Outbound HTTPS (443) access for PowerCLI module installation

## 🎯 Usage Examples

### Single VM Creation from Template

```powershell
.\vsphere-cli-create-vm-from-template.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -VMName "WebServer01" `
    -TemplateName "Windows2022-Template" `
    -DatastoreName "Production-SSD" `
    -ClusterName "Production-Cluster" `
    -PortGroupName "VLAN100-Production" `
    -CPUCount 4 `
    -MemoryGB 8 `
    -PowerOnAfterCreation
```

### Bulk VM Cloning

```powershell
.\vsphere-cli-clone-vm.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -SourceVM "Ubuntu22-Template" `
    -CloneCount 10 `
    -NamePrefix "WebNode" `
    -DatastoreName "Development-Storage" `
    -ClusterName "Dev-Cluster" `
    -LinkedClone `
    -PowerOnAfterClone
```

### Performance Monitoring with Alerts

```powershell
.\vsphere-cli-get-vm-performance.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -ClusterName "Production-Cluster" `
    -MetricType "All" `
    -ContinuousMonitoring `
    -AlertThresholds `
    -CPUThreshold 75 `
    -MemoryThreshold 80 `
    -RefreshInterval 30
```

### Infrastructure Inventory Report

```powershell
.\vsphere-cli-describe-inventory.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -ReportType "All" `
    -IncludeMetrics `
    -OutputFormat "HTML" `
    -OutputPath "Infrastructure-Report.html"
```

### Bulk VM Power Management

```powershell
# Start multiple VMs with snapshot creation
.\vsphere-cli-vm-power-operations.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -VMNames @("web01", "web02", "web03") `
    -Operation "Start" `
    -CreateSnapshot

# Graceful shutdown of all VMs in a cluster
.\vsphere-cli-vm-power-operations.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -ClusterName "Production-Cluster" `
    -Operation "Stop" `
    -GracefulShutdown

# Sequential restart with startup delays
.\vsphere-cli-vm-power-operations.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -VMNames @("app01", "app02") `
    -Operation "Restart" `
    -SequentialStartup `
    -StartupDelay 30
```

### Windows Update Management

```powershell
# Install critical and security updates
.\vsphere-cli-windows-updates.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -VMNames @("dc01", "file01") `
    -UpdateCategories @("Security", "Critical") `
    -DomainCredential (Get-Credential) `
    -AutoReboot `
    -CreateSnapshots

# Scan for updates without installation
.\vsphere-cli-windows-updates.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -VMNames @("web01", "web02") `
    -ScanOnly `
    -LocalCredential (Get-Credential)

# Concurrent update processing
.\vsphere-cli-windows-updates.ps1 `
    -VCenterServer "vcenter.domain.com" `
    -ClusterName "Production-Cluster" `
    -UpdateCategories @("Security", "Critical", "Important") `
    -DomainCredential (Get-Credential) `
    -AutoReboot `
    -MaxConcurrentVMs 3
```

## 🔐 Security Considerations

### Credential Management

- Scripts use Windows credential manager for vCenter authentication
- No passwords stored in plain text within scripts
- Support for domain-integrated authentication

### Certificate Handling

- PowerCLI certificate warnings disabled for lab environments
- Production environments should use proper SSL certificates
- Scripts can be modified to enforce certificate validation

### Permissions

- Follow principle of least privilege for vSphere service accounts
- Create dedicated service accounts for automation tasks
- Regular review and rotation of automation credentials

## 🛠️ Customization & Extension

### Adding New Scripts

Follow the established patterns:

1. **Parameter Validation**: Use `[ValidateSet]`, `[ValidatePattern]`, `[ValidateRange]`
2. **Error Handling**: Set `$ErrorActionPreference = 'Stop'` and use try/catch blocks
3. **PowerCLI Check**: Include the `Test-PowerCLIInstallation` function
4. **Documentation**: Complete PowerShell help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`

### Script Templates

Reference existing scripts for:

- Parameter block structure
- vCenter connection handling
- Object validation patterns
- Output formatting and reporting

## 🐛 Troubleshooting

### Common Issues

**PowerCLI Installation Fails**

- Ensure PowerShell execution policy allows module installation
- Run PowerShell as administrator if needed
- Check internet connectivity for PowerShell Gallery access

**vCenter Connection Issues**

- Verify vCenter FQDN/IP address accessibility
- Check firewall rules for port 443 outbound
- Validate credentials and permissions

**VM Creation Failures**

- Verify datastore has sufficient free space
- Check cluster resource availability
- Ensure templates exist and are accessible

**Performance Data Missing**

- Verify statistics collection is enabled in vCenter
- Check statistics levels and collection intervals
- Ensure appropriate permissions for statistics access

### Debug Mode

Enable PowerShell verbose output:

```powershell
$VerbosePreference = "Continue"
# Run script with -Verbose parameter
```

## 📚 Additional Resources

### VMware Documentation

- [vSphere 9.0 Documentation](https://docs.vmware.com/en/VMware-vSphere/9.0/)
- [PowerCLI User's Guide](https://developer.vmware.com/docs/powercli/)
- [vSphere API Reference](https://developer.vmware.com/docs/vsphere-automation/)

### PowerShell Resources

- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations)

---

## 📄 Script Inventory Summary

| Script                                    | Purpose                    | Key Features                                             |
| ----------------------------------------- | -------------------------- | -------------------------------------------------------- |
| `vsphere-cli-create-vm-from-template.ps1` | VM creation from templates | Guest customization, resource allocation, network config |
| `vsphere-cli-clone-vm.ps1`                | VM cloning operations      | Full/linked clones, bulk operations, async support       |
| `vsphere-cli-power-vm-operations.ps1`     | VM power management        | Start/stop/restart, graceful operations, bulk support    |
| `vsphere-cli-snapshot-vm.ps1`             | Snapshot management        | Create/revert/delete, cleanup policies, batch operations |
| `vsphere-cli-describe-inventory.ps1`      | Infrastructure reporting   | Comprehensive inventory, multiple formats, metrics       |
| `vsphere-cli-get-vm-performance.ps1`      | Performance monitoring     | Real-time metrics, alerting, continuous monitoring       |

## 🚀 Getting Started

1. **Clone or download** the scripts to your local system
2. **Review prerequisites** and ensure vSphere connectivity
3. **Test with non-production** environment first
4. **Customize parameters** for your specific environment
5. **Integrate with existing** automation workflows

For questions or contributions, follow the established patterns in the scripted-actions repository and maintain consistency with existing cloud platform scripts.
