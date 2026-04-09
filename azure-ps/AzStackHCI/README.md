# Azure Stack HCI Scripts

PowerShell scripts for deploying and managing Azure Stack HCI (Azure Local)
environments using the Az PowerShell module. Scripts cover both a lightweight
Azure VM host for nested-virtualization testing and the full Azure Arc Jumpstart
LocalBox evaluation environment.

## Prerequisites

- Az PowerShell module (`Install-Module Az`)
- Az.StackHCI module (`Install-Module Az.StackHCI`)
- Az.StackHCI.VM module (required by the image script)
- Active Azure subscription
- Appropriate permissions to create and manage Azure resources

## Available Scripts

| Script                                | Description                                                                                                                                                               |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `az-ps-deploy-azure-local-host.ps1`   | Deploy a Windows Server 2022 Azure VM with nested virtualization and Hyper-V for Azure Stack HCI testing                                                                  |
| `az-ps-remove-azure-local-host.ps1`   | Remove the Azure VM and all related networking resources created by the deploy-azure-local-host script                                                                    |
| `az-ps-deploy-azure-local-image.ps1`  | Create a generalized Azure Local VM image: provisions a VM on the HCI cluster, installs the XOAP agent, runs Sysprep, and registers the result as an Azure Local VM image |
| `az-ps-deploy-jumpstart-localbox.ps1` | Deploy the Azure Arc Jumpstart LocalBox (formerly HCIBox) full evaluation environment via Bicep template; supports a `-DryRun` mode                                       |
| `az-ps-remove-jumpstart-localbox.ps1` | Remove the entire LocalBox resource group and all contained resources                                                                                                     |

## Usage Examples

### Deploy Azure Local Host (nested-virtualization test VM)

```powershell
.\az-ps-deploy-azure-local-host.ps1 `
    -ResourceGroup "rg-azstackhci-test" `
    -VmName "vm-hci-host" `
    -Location "West Europe" `
    -AdminUser "azureadmin"
```

Run in dry-run mode to preview what would be created:

```powershell
.\az-ps-deploy-azure-local-host.ps1 `
    -ResourceGroup "rg-azstackhci-test" `
    -VmName "vm-hci-host" `
    -Location "West Europe" `
    -AdminUser "azureadmin" `
    -DryRun
```

### Remove Azure Local Host

```powershell
.\az-ps-remove-azure-local-host.ps1 `
    -ResourceGroup "rg-azstackhci-test" `
    -VmName "vm-hci-host"
```

### Deploy Azure Local VM Image

```powershell
$customLocationId = (
    "/subscriptions/<subscription-id>" +
    "/resourceGroups/rg-azlocal-prod" +
    "/providers/Microsoft.ExtendedLocation" +
    "/customLocations/cl-hci-cluster"
)
.\az-ps-deploy-azure-local-image.ps1 `
    -ResourceGroupName "rg-azlocal-prod" `
    -CustomLocationId $customLocationId `
    -Location "westeurope"
```

### Deploy Jumpstart LocalBox

```powershell
.\az-ps-deploy-jumpstart-localbox.ps1 `
    -Location "West Europe" `
    -ResourceGroup "rg-localbox" `
    -NamingPrefix "localbox" `
    -VmSize "Standard_D16s_v5" `
    -DeployBastion $true
```

> **Note:** LocalBox deployments take 60-90 minutes and can cost
> $800-1500 USD/month. Clean up resources when testing is complete.

### Remove Jumpstart LocalBox

```powershell
.\az-ps-remove-jumpstart-localbox.ps1 `
    -ResourceGroup "rg-localbox"
```

## Related Documentation

- [Azure Local (Stack HCI) documentation](https://learn.microsoft.com/en-us/azure/azure-local/)
- [Az.StackHCI module reference](https://learn.microsoft.com/en-us/powershell/module/az.stackhci/)
- [Azure Arc Jumpstart LocalBox](https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_hcibox)
