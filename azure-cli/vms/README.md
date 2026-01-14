# Azure CLI - Virtual Machine Scripts

This directory contains PowerShell scripts for managing Azure Virtual Machines using Azure CLI.

## Prerequisites

- Azure CLI 2.50+ installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions
- Azure CLI logged in (`az login`)
- Virtual Machine Contributor role or equivalent

## Available Scripts

### VM Management

- **az-cli-create-windows-vm.ps1** - Create Windows virtual machines
- **az-cli-create-linux-vm.ps1** - Create Linux virtual machines
- **az-cli-start-vm.ps1** - Start stopped VMs
- **az-cli-stop-vm.ps1** - Stop running VMs (deallocate)
- **az-cli-restart-vm.ps1** - Restart VMs
- **az-cli-delete-vm.ps1** - Delete VMs

### VM Scale Sets

- **az-cli-create-vm-scale-set.ps1** - Create VM Scale Sets for auto-scaling
- **az-cli-scale-vmss.ps1** - Scale VM Scale Sets up or down
- **az-cli-update-vmss.ps1** - Update Scale Set configuration

### Image Management

- **az-cli-create-image-gallery.ps1** - Create Azure Compute Gallery
- **az-cli-create-image-definition.ps1** - Create image definitions
- **az-cli-create-image-version.ps1** - Create image versions
- **az-cli-capture-vm-image.ps1** - Capture custom VM images

### VM Extensions

- Install and manage VM extensions
- Custom script extensions
- Diagnostic extensions
- Monitoring agents

## Usage Examples

### Create a Windows VM

```powershell
# Create resource group
az group create --name myResourceGroup --location eastus

# Create Windows VM
az vm create `
    --resource-group myResourceGroup `
    --name myWindowsVM `
    --image Win2022Datacenter `
    --admin-username azureuser `
    --admin-password 'P@ssw0rd1234!' `
    --size Standard_D2s_v3 `
    --nsg-rule RDP `
    --public-ip-sku Standard
```

### Create a Linux VM

```powershell
# Create Linux VM with SSH key
az vm create `
    --resource-group myResourceGroup `
    --name myLinuxVM `
    --image UbuntuLTS `
    --admin-username azureuser `
    --ssh-key-values ~/.ssh/id_rsa.pub `
    --size Standard_B2s `
    --nsg-rule SSH
```

### Create VM Scale Set

```powershell
# Create VMSS
az vmss create `
    --resource-group myResourceGroup `
    --name myScaleSet `
    --image UbuntuLTS `
    --upgrade-policy-mode automatic `
    --admin-username azureuser `
    --ssh-key-values ~/.ssh/id_rsa.pub `
    --instance-count 3 `
    --vm-sku Standard_B2s `
    --load-balancer myLoadBalancer
```

### Create Azure Compute Gallery and Image

```powershell
# Create gallery
az sig create `
    --resource-group myResourceGroup `
    --gallery-name myGallery

# Create image definition
az sig image-definition create `
    --resource-group myResourceGroup `
    --gallery-name myGallery `
    --gallery-image-definition myImageDef `
    --publisher myPublisher `
    --offer myOffer `
    --sku mySku `
    --os-type Windows `
    --os-state Generalized

# Create image version from VM
az sig image-version create `
    --resource-group myResourceGroup `
    --gallery-name myGallery `
    --gallery-image-definition myImageDef `
    --gallery-image-version 1.0.0 `
    --managed-image /subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Compute/images/myImage
```

## Azure VM Best Practices

- **Cost Optimization**:

  - Use B-series for burstable workloads
  - Leverage Azure Reserved Instances
  - Stop/deallocate VMs when not in use
  - Use Spot VMs for non-critical workloads
  - Right-size based on actual usage

- **Security**:

  - Use managed identities for authentication
  - Enable Azure Disk Encryption
  - Use Azure Bastion for secure access
  - Implement Just-In-Time VM access
  - Keep VMs patched and updated
  - Use network security groups properly

- **High Availability**:

  - Deploy across availability zones
  - Use availability sets for fault domains
  - Implement VM Scale Sets for auto-scaling
  - Use managed disks for better reliability
  - Implement proper backup strategies

- **Performance**:
  - Use Premium SSD for production workloads
  - Enable Accelerated Networking
  - Use proximity placement groups for low latency
  - Choose appropriate VM sizes
  - Monitor performance metrics

## VM Sizing Guidelines

### General Purpose (B, D, DC, E series)

- Balanced CPU-to-memory ratio
- Web servers, development, small databases

### Compute Optimized (F series)

- High CPU-to-memory ratio
- Medium traffic web servers, batch processes

### Memory Optimized (E, M series)

- High memory-to-CPU ratio
- Large databases, in-memory analytics

### Storage Optimized (L series)

- High disk throughput and IO
- Big Data, SQL, NoSQL databases

### GPU (N series)

- Graphics rendering, AI/ML workloads
- Video editing, 3D visualization

## Disk Types

- **Ultra Disk**: Highest performance, sub-millisecond latency
- **Premium SSD**: Production workloads, consistent performance
- **Standard SSD**: Cost-effective SSD option
- **Standard HDD**: Lowest cost, infrequent access

## Error Handling

Scripts include:

- Resource name validation
- Quota checks
- Image availability verification
- Network configuration validation
- Comprehensive error messages

## Related Documentation

- [Azure Virtual Machines Documentation](https://docs.microsoft.com/azure/virtual-machines/)
- [Azure CLI VM Commands](https://docs.microsoft.com/cli/azure/vm)
- [VM Sizes Documentation](https://docs.microsoft.com/azure/virtual-machines/sizes)
- [Azure Compute Gallery](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries)

## Support

For issues or questions, please refer to the main repository documentation.
