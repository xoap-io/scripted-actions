# 🔧 Nutanix PowerShell Automation Scripts

This collection provides comprehensive PowerShell scripts for managing Nutanix AHV clusters using the Nutanix PowerShell SDK. All scripts include automatic SDK installation and verification, following enterprise automation patterns.

## 📋 Prerequisites

```powershell
# Required PowerShell modules (auto-installed by scripts)
Install-Module -Name Nutanix.PowerShell.SDK -Force -AllowClobber
```

## 🚀 Core VM Operations (`vms/`)

### VM Provisioning & Management

1. **`nutanix-cli-create-vm.ps1`** - Create new VMs from scratch or images
   - VM creation with custom specifications
   - Resource allocation (CPU, memory, storage)
   - Network configuration and VLAN assignment
   - Nutanix PowerShell SDK auto-installation

2. **`nutanix-cli-clone-vm.ps1`** - Clone VMs and create templates
   - Full VM cloning with customization
   - Bulk cloning with auto-generated naming
   - Resource modification during cloning
   - Snapshot-based cloning support

3. **`nutanix-cli-vm-power-operations.ps1`** - Advanced VM power management
   - Start, stop, restart, suspend operations
   - Graceful vs. hard power operations with NGT integration
   - Sequential startup with configurable delays
   - Bulk operations with cluster targeting
   - Auto-snapshot creation before power operations
   - Comprehensive status reporting with uptime tracking

4. **`nutanix-cli-snapshot-vm.ps1`** - Snapshot management
   - Create, list, revert, delete snapshots
   - Snapshot cleanup with retention policies
   - Protection domain integration
   - Batch operations across multiple VMs

5. **`nutanix-cli-migrate-vm.ps1`** - VM migration operations
   - Live migration between AHV hosts
   - Storage migration between containers
   - Migration validation and compatibility checking
   - Bulk migration with safety checks

6. **`nutanix-cli-windows-updates.ps1`** - Windows Update management
   - Automated Windows update scanning and installation
   - Multiple update categories (Security, Critical, Important)
   - PSWindowsUpdate module auto-installation
   - Reboot management with completion tracking
   - Update history reporting and compliance checking
   - Concurrent VM processing with safety controls

## 🏗️ Infrastructure Management (`infrastructure/`)

### Cluster & Host Operations

7. **`nutanix-cli-cluster-operations.ps1`** - Cluster management
   - Cluster health monitoring and reporting
   - Node addition and removal operations
   - Cluster configuration management
   - Performance monitoring and alerting

8. **`nutanix-cli-host-operations.ps1`** - AHV host management
   - Host health status and diagnostics
   - Host maintenance mode operations
   - Host configuration and updates
   - Performance metrics collection

9. **`nutanix-cli-network-operations.ps1`** - Network management
   - Virtual switch and VLAN configuration
   - Network security policy management
   - IP address pool management
   - Network performance monitoring

10. **`nutanix-cli-protection-domains.ps1`** - Data protection
    - Protection domain creation and management
    - Backup schedule configuration
    - Remote site replication setup
    - Recovery point management

## 💾 Storage Management (`storage/`)

### Storage Operations

11. **`nutanix-cli-storage-containers.ps1`** - Storage container management
    - Container creation with deduplication/compression
    - Storage policy configuration
    - Capacity monitoring and alerting
    - Performance optimization

12. **`nutanix-cli-volume-groups.ps1`** - Volume group operations
    - iSCSI volume group creation and management
    - Volume attachment to VMs
    - Volume group snapshots and cloning
    - Performance monitoring

13. **`nutanix-cli-performance-monitor.ps1`** - Performance analysis
    - Cluster-wide performance metrics
    - VM performance analysis
    - Storage performance monitoring
    - Alerting and threshold management

## 🔧 Key Features

### Nutanix PowerShell SDK Integration

- **Automatic Installation**: All scripts check for and install Nutanix PowerShell SDK if missing
- **Version Compatibility**: Support for AOS 6.0+ and PC 2022.x+
- **Connection Management**: Secure credential handling and session management
- **Error Handling**: Comprehensive error handling with retry logic

### Parameter Validation

- **Resource IDs**: Validation for VM names, container names, cluster names
- **Network Configuration**: VLAN ID and IP address validation
- **Resource Limits**: CPU, memory, and storage capacity validation
- **UUID Support**: Support for both names and UUIDs for resource identification

### Operational Safety

- **Confirmation Prompts**: Force parameter to bypass confirmations
- **Backup Integration**: Auto-snapshot creation before destructive operations
- **Rollback Capability**: Safe operation rollback mechanisms
- **Audit Logging**: Comprehensive operation logging and reporting

## 🔌 Requirements

### Software Requirements

- **PowerShell 5.1** or later (Windows PowerShell or PowerShell Core)
- **Nutanix PowerShell SDK** (auto-installed by scripts)
- **Network connectivity** to Nutanix Prism Central/Element

### Nutanix Permissions

- **Cluster Admin** or appropriate role-based permissions
- **Prism Central** access for multi-cluster operations
- **Storage Admin** permissions for storage operations

### Network Requirements

- **Prism Central/Element Connectivity**: Network access (port 9440)
- **VM Network Access**: For Windows update operations
- **Inter-cluster connectivity**: For replication and migration

## 🎯 Usage Examples

### Single VM Creation

```powershell
.\nutanix-cli-create-vm.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMName "WebServer01" `
    -ClusterName "Production-Cluster" `
    -ContainerName "Production-Storage" `
    -NetworkName "VLAN100-Production" `
    -CPUCores 4 `
    -MemoryGB 8 `
    -DiskSizeGB 100 `
    -PowerOnAfterCreation
```

### Bulk VM Cloning

```powershell
.\nutanix-cli-clone-vm.ps1 `
    -PrismCentral "pc.domain.com" `
    -SourceVM "Ubuntu22-Template" `
    -CloneCount 10 `
    -NamePrefix "WebNode" `
    -ContainerName "Development-Storage" `
    -NetworkName "Dev-Network" `
    -PowerOnAfterClone
```

### Bulk VM Power Management

```powershell
# Start multiple VMs with snapshot creation
.\nutanix-cli-vm-power-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMNames @("web01", "web02", "web03") `
    -Operation "Start" `
    -CreateSnapshot

# Graceful shutdown of all VMs in a cluster
.\nutanix-cli-vm-power-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -ClusterName "Production-Cluster" `
    -Operation "Stop" `
    -GracefulShutdown

# Sequential restart with startup delays
.\nutanix-cli-vm-power-operations.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMNames @("app01", "app02") `
    -Operation "Restart" `
    -SequentialStartup `
    -StartupDelay 30
```

### Windows Update Management

```powershell
# Install critical and security updates
.\nutanix-cli-windows-updates.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMNames @("dc01", "file01") `
    -UpdateCategories @("Security", "Critical") `
    -DomainCredential (Get-Credential) `
    -AutoReboot `
    -CreateSnapshots

# Scan for updates without installation
.\nutanix-cli-windows-updates.ps1 `
    -PrismCentral "pc.domain.com" `
    -VMNames @("web01", "web02") `
    -ScanOnly `
    -LocalCredential (Get-Credential)

# Concurrent update processing
.\nutanix-cli-windows-updates.ps1 `
    -PrismCentral "pc.domain.com" `
    -ClusterName "Production-Cluster" `
    -UpdateCategories @("Security", "Critical", "Important") `
    -DomainCredential (Get-Credential) `
    -AutoReboot `
    -MaxConcurrentVMs 3
```

### Performance Monitoring

```powershell
# Generate performance report
.\nutanix-cli-performance-monitor.ps1 `
    -PrismCentral "pc.domain.com" `
    -ClusterName "Production-Cluster" `
    -MetricTypes @("CPU", "Memory", "Storage") `
    -ReportPath "cluster-performance.html"
```

### Storage Container Management

```powershell
# Create new storage container with compression
.\nutanix-cli-storage-containers.ps1 `
    -PrismCentral "pc.domain.com" `
    -ContainerName "Production-Container" `
    -ClusterName "Production-Cluster" `
    -EnableCompression `
    -EnableDeduplication `
    -ReplicationFactor 2
```

## 🔐 Security Considerations

### Credential Management

- Scripts use secure credential storage and Windows credential manager
- Support for certificate-based authentication
- No passwords stored in plain text within scripts

### Certificate Handling

- SSL certificate validation with bypass options for lab environments
- Support for custom CA certificates
- Secure communication with Prism Central/Element

### Permissions

- Follow principle of least privilege for Nutanix service accounts
- Role-based access control integration
- Audit trail for all operations

## 🛠️ Development Guidelines

### Adding New Scripts

1. **Parameter Validation**: Use `[ValidateSet]`, `[ValidatePattern]`, `[ValidateRange]`
2. **Error Handling**: Set `$ErrorActionPreference = 'Stop'` and use try/catch blocks
3. **SDK Check**: Include the `Test-NutanixSDKInstallation` function
4. **Documentation**: Complete PowerShell help with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`

### Script Templates

Use the template structure for consistent parameter blocks and error handling:

- Parameter block structure
- Nutanix SDK installation check
- Connection management
- Operation execution with error handling
- Result reporting and cleanup

## 🔍 Troubleshooting

**Nutanix PowerShell SDK Installation Fails**

- Ensure PowerShell execution policy allows module installation
- Check network connectivity to PowerShell Gallery
- Run PowerShell as Administrator for system-wide installation

**Connection to Prism Central/Element Fails**

- Verify network connectivity on port 9440
- Check firewall rules and security groups
- Validate credentials and permissions

**VM Operations Timeout**

- Increase timeout values for large VMs
- Check cluster resource availability
- Monitor storage and network performance

## 📚 Additional Resources

- [Nutanix PowerShell SDK Documentation](https://www.nutanix.dev/api-reference/)
- [Nutanix AHV Administration Guide](https://portal.nutanix.com/page/documents/details?targetId=AHV-Admin-Guide)
- [Nutanix Prism Central Guide](https://portal.nutanix.com/page/documents/details?targetId=Prism-Central-Guide)

---

⚠️ **Important**: Always test scripts in a development environment before running in production. These scripts can perform destructive operations.
