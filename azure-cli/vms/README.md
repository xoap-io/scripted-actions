# Virtual Machine Scripts

PowerShell scripts for managing Azure Virtual Machines, VM Scale Sets, Azure
Compute Gallery resources, and VM extensions using Azure CLI.

Scripts prefixed with `wip_` are works in progress and should not be used in
production without review.

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)

## Available Scripts

| Script | Description |
| --- | --- |
| `az-cli-create-image-definition.ps1` | Create an image definition in an Azure Compute Gallery |
| `az-cli-create-image-gallery.ps1` | Create an Azure Compute Gallery (Shared Image Gallery) |
| `az-cli-create-image-version.ps1` | Create a new image version in a Compute Gallery from an existing VM |
| `az-cli-create-vm-scale-set.ps1` | Create a Virtual Machine Scale Set with configurable orchestration mode and image |
| `az-cli-create-windows-vm.ps1` | Create a Windows Virtual Machine with networking, public IP, and NSG |
| `az-cli-delete-image-builder-windows.ps1` | Delete an Azure Image Builder template and associated resources for Windows |
| `az-cli-enable-EntraID-login-linux-vm.ps1` | Enable Entra ID (Azure AD) SSH login on a Linux VM via the AADSSHLoginForLinux extension |
| `az-cli-install-webserver-vm.ps1` | Install a web server on a VM via run-command and open the required ports |
| `az-cli-share-image-gallery.ps1` | Share an Azure Compute Gallery with a user by assigning the Reader role |
| `wip_az-cli-create-image-builder-linux.ps1` | (WIP) Create an Azure Image Builder template for Linux |
| `wip_az-cli-create-image-builder-windows.ps1` | (WIP) Create an Azure Image Builder template for Windows |
| `wip_az-cli-create-linux-vm.ps1` | (WIP) Create a Linux Virtual Machine |
| `wip_az-cli-create-specialized-vm.ps1` | (WIP) Create a specialized VM from a managed image |
| `wip_az-cli-delete-image-builder-linux.ps1` | (WIP) Delete an Azure Image Builder template and associated resources for Linux |

## Usage Examples

### Create a Windows VM

```powershell
.\az-cli-create-windows-vm.ps1 `
    -Name "vm-web-prod-01" `
    -UserName "azureuser" `
    -Password "P@ssw0rd1234!" `
    -ResourceGroup "rg-vms" `
    -Location "eastus" `
    -Image "Win2022Datacenter" `
    -Size "Standard_D2s_v3"
```

### Create an Azure Compute Gallery

```powershell
.\az-cli-create-image-gallery.ps1 `
    -AzResourceGroup "rg-images" `
    -AzLocation "eastus" `
    -AzGalleryName "myImageGallery"
```

### Create an Image Definition

```powershell
.\az-cli-create-image-definition.ps1 `
    -ImageDefinition "win2022-base" `
    -GalleryName "myImageGallery" `
    -ResourceGroup "rg-images" `
    -Publisher "MyOrg" `
    -Offer "WindowsServer" `
    -Sku "2022-Datacenter" `
    -OsType "Windows"
```

### Create an Image Version

```powershell
.\az-cli-create-image-version.ps1 `
    -AzResourceGroup "rg-images" `
    -AzGallery "myImageGallery" `
    -AzImageDefinition "win2022-base" `
    -AzGalleryImageVersion "1.0.0" `
    -AzTargetRegions "eastus" `
    -AzReplicaCount 1 `
    -AzSubscriptionId "00000000-0000-0000-0000-000000000000" `
    -AzVmName "vm-source"
```

### Create a VM Scale Set

```powershell
.\az-cli-create-vm-scale-set.ps1 `
    -AzResourceGroup "rg-vms" `
    -AzScaleSetName "vmss-web" `
    -AzOrchestrationMode "Flexible" `
    -AzSkuImage "UbuntuLTS" `
    -AzScaleSetInstanceCount 3 `
    -AzAdminUserName "azureuser"
```

### Enable Entra ID Login on a Linux VM

```powershell
.\az-cli-enable-EntraID-login-linux-vm.ps1 `
    -AzResourceGroup "rg-vms" `
    -AzExtensionName "Microsoft.Azure.ActiveDirectory" `
    -AzVmName "vm-linux-prod-01"
```

### Install a Web Server on a VM

```powershell
.\az-cli-install-webserver-vm.ps1 `
    -AzResourceGroup "rg-vms" `
    -AzVmName "vm-web-prod-01" `
    -Script "Install-WindowsFeature -name Web-Server -IncludeManagementTools" `
    -AzOpenPorts "80"
```

### Share an Image Gallery

```powershell
.\az-cli-share-image-gallery.ps1 `
    -AzResourceGroup "rg-images" `
    -AzGalleryName "myImageGallery" `
    -EmailAddress "user@example.com"
```

## Notes

- `az-cli-delete-image-builder-windows.ps1` removes the image template,
  role assignment, role definition, managed identity, and resource group.
  Run with caution.
- Image version creation can take several minutes depending on source VM
  size and target region replication count.
- Scripts prefixed with `wip_` are incomplete; review before using them.
