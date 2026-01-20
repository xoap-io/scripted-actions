# Azure CLI - Network Scripts

This directory contains PowerShell scripts for managing Azure networking resources using Azure CLI.

## Prerequisites

- Azure CLI 2.50+ installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions
- Azure CLI logged in (`az login`)
- Network Contributor role or equivalent

## Available Scripts

### Virtual Network Management

Scripts for managing Azure Virtual Networks (VNets):

- VNet creation and configuration
- Subnet management
- VNet peering
- Address space management

### Network Security

- Network Security Groups (NSGs)
- Application Security Groups (ASGs)
- Security rules configuration
- DDoS Protection

### Load Balancing

- Azure Load Balancer configuration
- Application Gateway setup
- Traffic Manager profiles
- Frontend IP configuration

### VPN and ExpressRoute

- VPN Gateway deployment
- Site-to-Site VPN configuration
- Point-to-Site VPN setup
- ExpressRoute circuit management

### DNS and Private Link

- Azure DNS zones
- Private DNS configuration
- Private Link services
- Private endpoints

### Network Monitoring

- Network Watcher
- Flow logs
- Connection monitoring
- Traffic analytics

## Usage Examples

### Create a Virtual Network

```powershell
# Login to Azure
az login

# Create resource group
az group create --name myResourceGroup --location eastus

# Create VNet
az network vnet create `
    --resource-group myResourceGroup `
    --name myVNet `
    --address-prefix 10.0.0.0/16 `
    --subnet-name mySubnet `
    --subnet-prefix 10.0.1.0/24
```

### Create Network Security Group

```powershell
# Create NSG
az network nsg create `
    --resource-group myResourceGroup `
    --name myNSG

# Add security rule
az network nsg rule create `
    --resource-group myResourceGroup `
    --nsg-name myNSG `
    --name AllowHTTPS `
    --priority 100 `
    --direction Inbound `
    --access Allow `
    --protocol Tcp `
    --destination-port-ranges 443
```

### Configure VNet Peering

```powershell
# Peer VNet1 to VNet2
az network vnet peering create `
    --resource-group myResourceGroup `
    --name VNet1-to-VNet2 `
    --vnet-name VNet1 `
    --remote-vnet VNet2 `
    --allow-vnet-access
```

## Azure Networking Best Practices

- **Architecture**:

  - Use hub-and-spoke topology for multiple VNets
  - Implement network segmentation
  - Plan IP addressing carefully
  - Use Azure Bastion for secure RDP/SSH

- **Security**:

  - Implement NSGs at subnet level
  - Use Azure Firewall for centralized control
  - Enable DDoS Protection Standard for critical workloads
  - Use Private Link for Azure services

- **Performance**:

  - Use proximity placement groups for low latency
  - Enable Accelerated Networking
  - Use appropriate SKUs for gateways and load balancers
  - Monitor network performance metrics

- **Cost Management**:
  - Minimize cross-region traffic
  - Use Azure Firewall instead of multiple NVAs
  - Right-size VPN/ExpressRoute circuits
  - Review bandwidth pricing

## Common Networking Patterns

### Hub-and-Spoke Topology

```
Hub VNet (10.0.0.0/16)
├── AzureFirewallSubnet (10.0.1.0/24)
├── GatewaySubnet (10.0.2.0/27)
└── Management Subnet (10.0.3.0/24)

Spoke VNet 1 (10.1.0.0/16) ← Peered to Hub
Spoke VNet 2 (10.2.0.0/16) ← Peered to Hub
```

### Network Security Layers

1. Azure Firewall / NVA (perimeter)
2. Network Security Groups (subnet level)
3. Application Security Groups (workload level)

## Error Handling

Scripts include:

- Resource name validation
- CIDR block validation
- Quota checks
- Dependency verification
- Comprehensive error messages

## Related Documentation

- [Azure Virtual Network Documentation](https://docs.microsoft.com/azure/virtual-network/)
- [Azure CLI Network Commands](https://docs.microsoft.com/cli/azure/network)
- [Azure Network Security Best Practices](https://docs.microsoft.com/azure/security/fundamentals/network-best-practices)

## Support

For issues or questions, please refer to the main repository documentation.
