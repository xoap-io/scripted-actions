# Azure CLI - AVD (Azure Virtual Desktop) Scripts

This directory contains PowerShell scripts for managing Azure Virtual Desktop using Azure CLI.

## Prerequisites

- Azure CLI 2.50+ installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions
- Azure CLI logged in (`az login`)
- AVD resources provisioned (host pools, workspaces, app groups)

## Available Scripts

Scripts for managing Azure Virtual Desktop environments:

### Host Pool Management

- Host pool creation and configuration
- Session host management
- Scaling configuration

### Application Group Management

- Desktop and RemoteApp groups
- User assignments
- Application publishing

### Workspace Management

- Workspace creation
- Application group associations
- User access management

### Session Host Operations

- VM provisioning
- Domain join operations
- AVD agent installation
- Health monitoring

## Usage Examples

### Typical Workflow

```powershell
# Login to Azure
az login

# Set subscription
az account set --subscription "Your-Subscription-Name"

# Run AVD scripts
.\avd-script.ps1 -ResourceGroup myRG -HostPoolName myPool
```

## Azure Virtual Desktop Best Practices

- **Cost Optimization**:

  - Use auto-scaling to adjust capacity
  - Leverage Azure Reserved Instances
  - Implement start/stop schedules
  - Use appropriate VM sizes

- **Security**:

  - Enable MFA for all users
  - Use Conditional Access policies
  - Implement network security groups
  - Enable Azure AD integration
  - Use Trusted Launch VMs

- **Performance**:

  - Deploy in regions close to users
  - Use Premium SSD for OS disks
  - Enable Accelerated Networking
  - Configure appropriate FSLogix settings

- **Management**:
  - Use Azure Monitor for diagnostics
  - Implement disaster recovery
  - Regular image updates
  - Tag resources for organization

## Common Configuration

### Required Permissions

- Virtual Machine Contributor
- Desktop Virtualization Contributor
- Network Contributor
- Storage Account Contributor

### Network Requirements

- Virtual network with subnets
- DNS configuration for AD DS
- Network security groups
- Azure Firewall or NSG rules for AVD endpoints

## Error Handling

Scripts include:

- Resource existence validation
- Permission checks
- Network connectivity verification
- Comprehensive error messages

## Related Documentation

- [Azure Virtual Desktop Documentation](https://docs.microsoft.com/azure/virtual-desktop/)
- [Azure CLI AVD Commands](https://docs.microsoft.com/cli/azure/desktopvirtualization)
- [AVD Architecture Guide](https://docs.microsoft.com/azure/architecture/example-scenario/wvd/windows-virtual-desktop)

## Support

For issues or questions, please refer to the main repository documentation.
