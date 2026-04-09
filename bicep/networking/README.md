# bicep/networking/

Bicep-based PowerShell scripts for deploying Azure networking resources.

## Scripts

| Script                  | Description                                         |
| ----------------------- | --------------------------------------------------- |
| `bicep-deploy-vnet.ps1` | Deploy a VNet with up to three configurable subnets |

## bicep-deploy-vnet.ps1

Deploys an Azure Virtual Network with up to three subnets. Only the
first subnet is required; subnets two and three are optional and are
included in the template only when both their name and prefix are
provided. DDoS Protection Standard can optionally be enabled.

### Parameters

| Parameter              | Required | Default                      | Description                                   |
| ---------------------- | -------- | ---------------------------- | --------------------------------------------- |
| `ResourceGroupName`    | Yes      | —                            | Target Azure Resource Group                   |
| `VnetName`             | Yes      | —                            | Name of the virtual network                   |
| `Location`             | Yes      | —                            | Azure region (e.g. `westeurope`)              |
| `AddressPrefix`        | Yes      | —                            | VNet address space in CIDR (e.g. 10.0.0.0/16) |
| `Subnet1Name`          | No       | `default`                    | Name of the first subnet                      |
| `Subnet1Prefix`        | No       | `10.0.0.0/24`                | CIDR prefix of the first subnet               |
| `Subnet2Name`          | No       | —                            | Name of the optional second subnet            |
| `Subnet2Prefix`        | No       | —                            | CIDR prefix of the optional second subnet     |
| `Subnet3Name`          | No       | —                            | Name of the optional third subnet             |
| `Subnet3Prefix`        | No       | —                            | CIDR prefix of the optional third subnet      |
| `EnableDdosProtection` | No       | `$false` (switch)            | Enable DDoS Protection Standard               |
| `DeploymentName`       | No       | `<VnetName>-deployment-<ts>` | ARM deployment name                           |

### Usage

```powershell
# Deploy a VNet with three subnets
.\bicep-deploy-vnet.ps1 `
    -ResourceGroupName "rg-network-prod" `
    -VnetName "vnet-prod-eastus" `
    -Location "eastus" `
    -AddressPrefix "10.10.0.0/16" `
    -Subnet1Name "snet-web" `
    -Subnet1Prefix "10.10.1.0/24" `
    -Subnet2Name "snet-app" `
    -Subnet2Prefix "10.10.2.0/24" `
    -Subnet3Name "snet-db" `
    -Subnet3Prefix "10.10.3.0/24"

# Deploy a VNet with DDoS protection and a single default subnet
.\bicep-deploy-vnet.ps1 `
    -ResourceGroupName "rg-dev" `
    -VnetName "vnet-dev" `
    -Location "northeurope" `
    -AddressPrefix "192.168.0.0/20" `
    -EnableDdosProtection
```
