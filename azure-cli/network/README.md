# Network Scripts

PowerShell scripts for managing Azure networking resources using Azure CLI.

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)

## Available Scripts

| Script                                     | Description                                                                      |
| ------------------------------------------ | -------------------------------------------------------------------------------- |
| `az-cli-add-nsg-rule.ps1`                  | Add a security rule to an existing Network Security Group                        |
| `az-cli-add-route.ps1`                     | Add a route to an existing route table                                           |
| `az-cli-associate-nsg-subnet.ps1`          | Associate or disassociate an NSG with a VNet subnet                              |
| `az-cli-associate-route-table.ps1`         | Associate a route table with a subnet                                            |
| `az-cli-bulk-network-operations.ps1`       | Perform bulk create, delete, configure, or list operations on network resources  |
| `az-cli-create-application-gateway.ps1`    | Create an Application Gateway with backend pools, listeners, and optional WAF    |
| `az-cli-create-bastion-host.ps1`           | Create an Azure Bastion host for secure RDP/SSH without public IP exposure       |
| `az-cli-create-load-balancer.ps1`          | Create a public or internal Load Balancer                                        |
| `az-cli-create-local-network-gateway.ps1`  | Create a local network gateway for site-to-site VPN                              |
| `az-cli-create-nat-gateway.ps1`            | Create an Azure NAT Gateway and optionally associate it with a subnet            |
| `az-cli-create-network-security-group.ps1` | Create a Network Security Group                                                  |
| `az-cli-create-network-watcher.ps1`        | Create a Network Watcher instance in a region                                    |
| `az-cli-create-private-endpoint.ps1`       | Create a private endpoint for a PaaS service within a virtual network            |
| `az-cli-create-public-ip.ps1`              | Create a public IP address                                                       |
| `az-cli-create-route-table.ps1`            | Create a route table                                                             |
| `az-cli-create-subnet.ps1`                 | Create a subnet within an existing virtual network                               |
| `az-cli-create-virtual-network.ps1`        | Create a virtual network with a subnet, optional DDoS protection, and encryption |
| `az-cli-create-vnet-peering.ps1`           | Create a VNet peering between two virtual networks                               |
| `az-cli-create-vpn-connection.ps1`         | Create a VPN connection between gateways                                         |
| `az-cli-create-vpn-gateway.ps1`            | Create a VPN Gateway with optional BGP, active-active, and point-to-site support |
| `az-cli-delete-network-security-group.ps1` | Delete a Network Security Group                                                  |
| `az-cli-delete-route-table.ps1`            | Delete a route table                                                             |
| `az-cli-delete-subnet.ps1`                 | Delete a subnet from a virtual network                                           |
| `az-cli-delete-vnet-peering.ps1`           | Delete a VNet peering                                                            |
| `az-cli-enable-ddos-protection.ps1`        | Enable Azure DDoS Network Protection on a VNet, optionally creating a DDoS plan  |
| `az-cli-list-network-resources.ps1`        | List network resources in a subscription or resource group                       |
| `az-cli-monitor-network-resources.ps1`     | Monitor network resource health and metrics                                      |
| `az-cli-test-network-connectivity.ps1`     | Test network connectivity using Azure Network Watcher                            |

## Usage Examples

### Create a Virtual Network

```powershell
.\az-cli-create-virtual-network.ps1 `
    -Name "prod-vnet" `
    -ResourceGroup "rg-network" `
    -AddressPrefixes "10.0.0.0/16" `
    -Location "eastus" `
    -SubnetName "default" `
    -SubnetPrefixes "10.0.1.0/24"
```

### Create a Network Security Group

```powershell
.\az-cli-create-network-security-group.ps1 `
    -Name "web-nsg" `
    -ResourceGroup "rg-network" `
    -Location "eastus" `
    -Tags "environment=production tier=web"
```

### Add an NSG Rule

```powershell
.\az-cli-add-nsg-rule.ps1 `
    -NSGName "web-nsg" `
    -ResourceGroup "rg-network" `
    -RuleName "AllowHTTPS" `
    -Priority 100 `
    -Direction "Inbound" `
    -Access "Allow" `
    -Protocol "Tcp" `
    -SourceAddressPrefix "*" `
    -DestinationPortRange "443"
```

### Create a VPN Gateway

```powershell
.\az-cli-create-vpn-gateway.ps1 `
    -GatewayName "prod-vpn-gw" `
    -ResourceGroup "rg-network" `
    -Location "eastus" `
    -VNetName "prod-vnet" `
    -GatewaySubnetName "GatewaySubnet" `
    -PublicIPName "vpn-gw-pip" `
    -SKU "VpnGw2"
```

### Create an Azure Bastion Host

```powershell
.\az-cli-create-bastion-host.ps1 `
    -Name "prod-bastion" `
    -ResourceGroup "rg-network" `
    -VNetName "prod-vnet" `
    -Location "eastus" `
    -PublicIPAddress "bastion-pip"
```

### Perform Bulk Network Operations

```powershell
.\az-cli-bulk-network-operations.ps1 `
    -Operation "Create" `
    -ResourceType "PublicIP" `
    -ResourceGroup "rg-bulk" `
    -Location "East US" `
    -NamePrefix "bulk-pip" `
    -Count 5
```

### Create a Private Endpoint

```powershell
$storageId = "/subscriptions/<sub-id>/resourceGroups/rg-storage" +
    "/providers/Microsoft.Storage/storageAccounts/mystorageacct"

.\az-cli-create-private-endpoint.ps1 `
    -ResourceGroupName "rg-network" `
    -EndpointName "pe-storage" `
    -VnetName "prod-vnet" `
    -SubnetName "private-endpoints" `
    -ServiceResourceId $storageId `
    -GroupId "blob"
```

### Create a NAT Gateway

```powershell
.\az-cli-create-nat-gateway.ps1 `
    -ResourceGroupName "rg-network" `
    -NatGatewayName "nat-gw-prod" `
    -Location "eastus" `
    -PublicIpName "nat-gw-pip" `
    -VnetName "prod-vnet" `
    -SubnetName "private-subnet"
```

### Enable DDoS Protection on a VNet

```powershell
.\az-cli-enable-ddos-protection.ps1 `
    -ResourceGroupName "rg-network" `
    -VnetName "prod-vnet" `
    -DdosPlanName "ddos-plan-prod" `
    -Location "eastus"
```

## Notes

- The `-DryRun` switch is available on bulk and monitoring scripts to preview
  changes without executing them.
- Use `-Tags` in `key1=value1 key2=value2` format across all scripts.
- VPN Gateway creation can take 20-45 minutes to complete.
- Azure Bastion Standard SKU is required for tunneling and IP-based
  connections.
- Creating a private endpoint automatically disables private endpoint network
  policies on the target subnet (required by Azure).
- DDoS Network Protection plans are billed at a flat monthly rate regardless
  of the number of protected resources. Consider sharing a plan across VNets.
