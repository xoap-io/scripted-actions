# Azure PowerShell - Azure Stack HCI Scripts

This directory contains PowerShell scripts for managing Azure Stack HCI using Azure PowerShell modules.

## Prerequisites

- Azure PowerShell modules installed:
  - `Install-Module -Name Az.StackHCI`
  - `Install-Module -Name Az.Compute`
  - `Install-Module -Name Az.Network`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure Stack HCI cluster deployed
- Appropriate permissions for Stack HCI management

## About Azure Stack HCI

Azure Stack HCI is a hyperconverged infrastructure (HCI) cluster solution that hosts virtualized Windows and Linux workloads and their storage in a hybrid on-premises environment. It combines:

- Windows Server Hyper-V virtualization
- Software-defined storage (Storage Spaces Direct)
- Software-defined networking
- Azure Arc integration

## Available Scripts

Scripts in this directory help manage:

- Azure Stack HCI cluster registration
- VM management on HCI clusters
- Storage configuration
- Network configuration
- Azure Arc integration
- Update and patch management

## Usage Examples

### Register Azure Stack HCI

```powershell
# Connect to Azure
Connect-AzAccount

# Register cluster
Register-AzStackHCI `
    -SubscriptionId "your-subscription-id" `
    -ResourceGroupName "HCI-RG" `
    -ResourceName "MyHCICluster" `
    -Region "EastUS"
```

### Manage VMs on Stack HCI

```powershell
# Create VM using Azure PowerShell
New-AzVM `
    -ResourceGroupName "HCI-RG" `
    -Name "MyVM" `
    -Location "EastUS" `
    -VirtualMachineSize "Standard_D2s_v3"
```

## Azure Stack HCI Best Practices

- **Deployment**:

  - Use validated hardware from Microsoft partners
  - Implement proper network segregation
  - Plan storage capacity appropriately
  - Use redundant network paths

- **Management**:

  - Enable Azure Arc integration
  - Implement cluster-aware updating
  - Monitor with Azure Monitor
  - Regular backup of cluster configuration

- **Security**:

  - Enable BitLocker encryption
  - Use secured-core servers
  - Implement network microsegmentation
  - Regular security updates

- **Performance**:
  - Use NVMe or SSD for cache tier
  - Proper RDMA configuration
  - Monitor Storage Spaces Direct health
  - Balance VM workloads across nodes

## Key Components

### Storage Spaces Direct (S2D)

- Software-defined storage
- Local storage pooling
- Automatic data replication
- Cache and capacity tiers

### Software-Defined Networking (SDN)

- Network virtualization
- Software load balancing
- Distributed firewall
- Gateway services

### Windows Admin Center

- Web-based management interface
- Cluster management
- VM management
- Performance monitoring

## Error Handling

Scripts include:

- Cluster connectivity checks
- Azure registration validation
- Resource availability verification
- Comprehensive error messages

## Related Documentation

- [Azure Stack HCI Documentation](https://docs.microsoft.com/azure-stack/hci/)
- [Azure Stack HCI PowerShell](https://docs.microsoft.com/powershell/module/az.stackhci/)
- [Windows Admin Center](https://docs.microsoft.com/windows-server/manage/windows-admin-center/overview)

## Support

For issues or questions, please refer to the main repository documentation.
