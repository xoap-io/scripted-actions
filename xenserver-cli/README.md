# XenServer CLI Scripts Collection

This collection provides comprehensive PowerShell scripts for managing XenServer 8 infrastructure using the xe CLI. All scripts include parameter validation and error handling, following the established patterns of the scripted-actions repository.

## 📁 Directory Structure

```
xenserver-cli/
├── vms/                    # Virtual Machine operations
├── infrastructure/         # Host and pool management
├── storage/               # Storage repository operations
├── network/               # Network configuration and management
└── README.md              # This documentation
```

## 🚀 Core VM Operations (`vms/`)

### VM Power Management

1. **`xenserver-cli-power-vm-operations.ps1`** - Comprehensive VM power operations

   - Start, stop, restart, suspend, reset operations
   - Graceful vs. hard power operations
   - Sequential startup with configurable delays
   - Bulk operations with pool-wide targeting
   - Automatic status reporting with uptime tracking

2. **`xenserver-cli-vm-clone.ps1`** - VM cloning operations

   - Fast clone using storage-level operations
   - Full copy without CoW chains
   - Resource modification during cloning
   - Batch cloning with auto-generated naming

3. **`xenserver-cli-vm-snapshot.ps1`** - Snapshot management

   - Create, list, revert, delete snapshots
   - Checkpoint and quiesce support
   - Snapshot retention policies
   - Batch operations across multiple VMs

4. **`xenserver-cli-vm-migrate.ps1`** - VM migration operations
   - Live migration between hosts
   - Storage migration between SRs
   - Cross-pool migration support
   - Migration validation and compatibility checking

## 🏗️ Infrastructure Management (`infrastructure/`)

### Host & Pool Operations

1. **`xenserver-cli-host-operations.ps1`** - Comprehensive host management

   - Host enable/disable operations
   - Maintenance mode management
   - Host evacuation with live migration
   - Host power operations (reboot, shutdown)
   - Host backup and restore

2. **`xenserver-cli-pool-operations.ps1`** - Pool management
   - Pool creation and configuration
   - Host join/eject operations
   - Pool master designation
   - HA configuration
   - Pool-wide updates and patches

## 📦 Storage Management (`storage/`)

### SR Operations

1. **`xenserver-cli-sr-operations.ps1`** - Storage repository management

   - Create, destroy, and forget SRs
   - SR scanning and updates
   - PBD management (plug/unplug)
   - Storage type support (NFS, iSCSI, Local VHD)

2. **`xenserver-cli-vdi-operations.ps1`** - Virtual disk management
   - VDI creation and deletion
   - VDI resize and clone operations
   - VDI export/import
   - Snapshot and backup operations

## 🌐 Network Management (`network/`)

### Network Configuration

1. **`xenserver-cli-network-operations.ps1`** - Virtual network management

   - Network creation and destruction
   - VLAN configuration
   - Bond creation for NIC teaming
   - PIF reconfiguration

2. **`xenserver-cli-vif-operations.ps1`** - Virtual interface management
   - VIF creation and attachment
   - Network interface hotplug
   - QoS configuration
   - MAC address management

## 🔧 Key Features

### xe CLI Integration

- **Native CLI Commands**: All scripts use the native `xe` CLI commands
- **Connection Management**: Automatic authentication with credential caching
- **Remote Execution**: Support for remote pool operations
- **Error Handling**: Comprehensive error handling with meaningful messages

### Parameter Validation

- **Resource UUIDs**: Validation for VM UUIDs, host UUIDs, SR UUIDs
- **Network Configuration**: IP address and CIDR validation
- **Resource Limits**: CPU core and memory limits validation
- **PowerShell Best Practices**: CmdletBinding with parameter sets

### Operational Safety

- **Confirmation Prompts**: Force parameter to bypass confirmations
- **Pre-flight Checks**: Validation of all required XenServer objects
- **Idempotency**: Safe to run multiple times without side effects
- **Status Reporting**: Detailed output of operations and results

## 📋 Prerequisites

### XenServer Requirements

- XenServer 8.x or later
- Network access to XenServer pool coordinator
- Valid credentials for pool administrator

### xe CLI Installation

#### On XenServer Host

The xe CLI is installed by default on all XenServer hosts. Access it via:

- SSH to the host
- XenCenter console tab

#### On Windows

1. Install XenCenter
2. The `xe.exe` command is located at: `C:\Program Files (x86)\XenServer\XenCenter`
3. Add to system PATH for easier access

#### On Linux (RPM-based)

```bash
# Install from XenServer installation ISO
rpm -ivh xapi-xe-BUILD.x86_64.rpm
```

### PowerShell Configuration

```powershell
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Set environment variable for remote operations
$env:XE_EXTRA_ARGS = "server=<host>,username=<user>,password=<password>"
```

## 🔐 Authentication

### Session-based Authentication

```powershell
# Authenticate and store session
.\xenserver-cli-power-vm-operations.ps1 -PoolCoordinator "xenserver.domain.com" `
    -Username "root" -Password "password" -VMName "TestVM" -Operation "Start"
```

### Environment Variable Authentication

```powershell
# Set environment variable (Linux/Mac)
export XE_EXTRA_ARGS="server=xenserver.domain.com,username=root,password=password"

# Set environment variable (Windows PowerShell)
$env:XE_EXTRA_ARGS = "server=xenserver.domain.com,username=root,password=password"

# Run command without credentials
.\xenserver-cli-power-vm-operations.ps1 -VMName "TestVM" -Operation "Start"
```

## 📝 Usage Examples

### VM Operations

```powershell
# Start a VM
.\vms\xenserver-cli-power-vm-operations.ps1 -PoolCoordinator "xenserver.local" `
    -VMName "WebServer01" -Operation "Start"

# Clone a VM
.\vms\xenserver-cli-vm-clone.ps1 -PoolCoordinator "xenserver.local" `
    -VMName "Template-Ubuntu" -NewVMName "WebServer02"

# Create VM snapshot
.\vms\xenserver-cli-vm-snapshot.ps1 -PoolCoordinator "xenserver.local" `
    -VMName "WebServer01" -SnapshotName "Before-Update" -Operation "Create"
```

### Host Operations

```powershell
# Enable maintenance mode
.\infrastructure\xenserver-cli-host-operations.ps1 -PoolCoordinator "xenserver.local" `
    -HostName "xenhost01.local" -Operation "EnterMaintenance" -EvacuateVMs

# Reboot host
.\infrastructure\xenserver-cli-host-operations.ps1 -PoolCoordinator "xenserver.local" `
    -HostName "xenhost01.local" -Operation "Reboot" -Force
```

### Storage Operations

```powershell
# Create NFS SR
.\storage\xenserver-cli-sr-operations.ps1 -PoolCoordinator "xenserver.local" `
    -Operation "Create" -SRName "NFS-Storage" -SRType "nfs" `
    -ServerPath "nfs-server.local:/exports/xen"

# Resize VDI
.\storage\xenserver-cli-vdi-operations.ps1 -PoolCoordinator "xenserver.local" `
    -VDIUUID "12345678-1234-1234-1234-123456789012" -Operation "Resize" `
    -NewSize 100GB
```

### Network Operations

```powershell
# Create VLAN network
.\network\xenserver-cli-network-operations.ps1 -PoolCoordinator "xenserver.local" `
    -Operation "CreateVLAN" -NetworkName "VLAN-100" -VLANTag 100 `
    -PIFUUID "87654321-4321-4321-4321-210987654321"

# Create NIC bond
.\network\xenserver-cli-network-operations.ps1 -PoolCoordinator "xenserver.local" `
    -Operation "CreateBond" -BondName "bond0" `
    -PIFUUIDs @("uuid1","uuid2") -BondMode "active-backup"
```

## 🎯 Best Practices

1. **Always test in non-production** - Test all scripts in a development environment first
2. **Use Force parameter cautiously** - Only use `-Force` when you understand the impact
3. **Monitor operations** - Use `-Verbose` for detailed operation logs
4. **Backup before major changes** - Always backup VMs and configurations before major operations
5. **Document custom configurations** - Keep track of customizations and deviations
6. **Use UUID over names** - UUIDs are more reliable for automation than names
7. **Implement error handling** - Wrap script executions in try/catch blocks for automation

## 🔍 Troubleshooting

### Common Issues

1. **Connection Failures**

   - Verify network connectivity to pool coordinator
   - Check credentials and permissions
   - Ensure xe CLI is properly installed

2. **Command Not Found**

   - Add xe.exe to system PATH (Windows)
   - Verify xapi-xe package installed (Linux)
   - Use full path to xe command

3. **Permission Denied**

   - Verify user has pool admin rights
   - Check RBAC role assignments
   - Try with root/administrator account

4. **UUID Not Found**
   - List available resources first
   - Use `xe vm-list`, `xe host-list`, etc.
   - Verify resource exists in the pool

## 📚 Additional Resources

- [XenServer 8 Documentation](https://docs.xenserver.com/en-us/xenserver/8)
- [xe CLI Reference](https://docs.xenserver.com/en-us/xenserver/8/command-line-interface)
- [XenServer System Requirements](https://docs.xenserver.com/en-us/xenserver/8/system-requirements)
- [XenServer Community Forums](https://discussions.xenserver.com/)

## 🤝 Contributing

When adding new scripts to this collection:

1. Follow the established naming convention: `xenserver-cli-[category]-[action].ps1`
2. Include comprehensive comment-based help
3. Use CmdletBinding and parameter validation
4. Implement proper error handling with try/catch
5. Test with XenServer 8.x
6. Document all parameters and provide examples

## 📄 License

See the repository's main LICENSE file for licensing information.

## 🔖 Version History

- **1.0.0** (2026-01-14) - Initial release with core VM, infrastructure, storage, and network scripts
