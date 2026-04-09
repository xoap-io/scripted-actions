# bicep/vms/

Bicep-based PowerShell scripts for deploying Azure Virtual Machines.

## Scripts

| Script                        | Description                                         |
| ----------------------------- | --------------------------------------------------- |
| `bicep-deploy-windows-vm.ps1` | Deploy a Windows Server 2022 VM with NIC, VNet, NSG |

## bicep-deploy-windows-vm.ps1

Deploys a full Windows Server 2022 virtual machine stack including:

- Virtual Network and subnet (10.0.0.0/16 / 10.0.0.0/24)
- Network Security Group with an inbound RDP (port 3389) allow rule
- Network Interface Card
- Optional Standard public IP address
- Windows Server 2022 Datacenter Azure Edition VM on Premium LRS disk

### Parameters

| Parameter           | Required | Default                    | Description                              |
| ------------------- | -------- | -------------------------- | ---------------------------------------- |
| `ResourceGroupName` | Yes      | —                          | Target Azure Resource Group              |
| `VmName`            | Yes      | —                          | Name of the virtual machine              |
| `Location`          | Yes      | —                          | Azure region (e.g. `eastus`)             |
| `AdminUsername`     | Yes      | —                          | VM administrator username                |
| `AdminPassword`     | Yes      | —                          | VM administrator password (SecureString) |
| `VmSize`            | No       | `Standard_DS1_v2`          | Azure VM size SKU                        |
| `VnetName`          | No       | `<VmName>-vnet`            | Virtual network name                     |
| `SubnetName`        | No       | `default`                  | Subnet name                              |
| `AddPublicIp`       | No       | `$false` (switch)          | Attach a Standard public IP              |
| `DeploymentName`    | No       | `<VmName>-deployment-<ts>` | ARM deployment name                      |

### Usage

```powershell
# Deploy a VM with a public IP
.\bicep-deploy-windows-vm.ps1 `
    -ResourceGroupName "rg-prod-eastus" `
    -VmName "vm-web-01" `
    -Location "eastus" `
    -AdminUsername "azureadmin" `
    -AdminPassword (ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force) `
    -AddPublicIp

# Deploy a VM without a public IP, custom size
.\bicep-deploy-windows-vm.ps1 `
    -ResourceGroupName "rg-dev" `
    -VmName "vm-dev-01" `
    -Location "westeurope" `
    -AdminUsername "localadmin" `
    -AdminPassword (ConvertTo-SecureString "MyS3cur3Pass!" -AsPlainText -Force) `
    -VmSize "Standard_B2s" `
    -VnetName "vnet-dev" `
    -SubnetName "snet-vms"
```
