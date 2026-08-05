# Azure Stack HCI (Azure Local) Scripts

PowerShell scripts for deploying and operating Azure Local (Azure Stack HCI)
environments using the Az PowerShell module. Scripts cover lab deployment
(nested-virtualization host, Azure Arc Jumpstart LocalBox), VM image
management (create, update, replicate, remove), VM operations (deploy, start,
stop, restart, resize, remove, data disks), cluster infrastructure objects
(logical networks, storage paths) and Azure Virtual Desktop on Azure Local
(control plane and session host deployment).

## Prerequisites

- Az PowerShell module (`Install-Module Az`)
- Az.StackHCIVM module 1.1.0+ (`Install-Module Az.StackHCIVM`)
- Az.DesktopVirtualization module (for the AVD scripts)
- Active Azure subscription and an Azure Local cluster with the Arc resource
  bridge configured (except for the lab deployment scripts, which create one)
- Hyper-V PowerShell module and CSV access for the image capture/copy scripts
  (see "Run location" below)
- Appropriate permissions to create and manage Azure resources

## Default environment

The operational scripts ship with defaults that match the XOAP Jumpstart
LocalBox deployment and can all be overridden via parameters:

| Setting         | Default                                                       |
| --------------- | ------------------------------------------------------------- |
| Resource group  | `AzureLocal`                                                  |
| Location        | `westeurope`                                                  |
| Custom location | `.../resourceGroups/AzureLocal/.../customLocations/jumpstart` |
| Cluster         | `localboxcluster` (nodes `AzLHOST1` / `AzLHOST2`)             |
| Logical network | `localboxcluster-InfraLNET` (192.168.1.0/24, static)          |
| Hyper-V switch  | `ConvergedSwitch(compute_management)`                         |
| Storage path    | `sp-images` -> `C:\ClusterStorage\UserStorage_2\Images`       |

> **Note:** the `localboxcluster-InfraLNET` IP pool is small
> (192.168.1.101-103). Create a dedicated workload network with
> `az-ps-create-azure-local-logical-network.ps1` (defaults to `lnet-vms`,
> pool 192.168.1.200-240) before deploying several VMs.

## Available Scripts

### Lab / host deployment

| Script                                | Description                                                                                              |
| ------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `az-ps-deploy-azure-local-host.ps1`   | Deploy a Windows Server 2022 Azure VM with nested virtualization and Hyper-V for Azure Stack HCI testing |
| `az-ps-remove-azure-local-host.ps1`   | Remove the Azure VM and all related networking resources created by the deploy-azure-local-host script   |
| `az-ps-deploy-jumpstart-localbox.ps1` | Deploy the Azure Arc Jumpstart LocalBox full evaluation environment via Bicep template (`-DryRun` mode)  |
| `az-ps-remove-jumpstart-localbox.ps1` | Remove the entire LocalBox resource group and all contained resources                                    |

### Image management

| Script                               | Description                                                                                                                     |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------- |
| `az-ps-create-azure-local-image.ps1` | Register a VM image from the Azure Marketplace (URN or publisher/offer/sku/version) or from a VHDX on cluster storage           |
| `az-ps-deploy-azure-local-image.ps1` | Build a generalized golden image: deploy a builder VM from a base VHDX, install the XOAP agent, sysprep and register the result |
| `az-ps-update-azure-local-image.ps1` | Refresh an existing image: builder VM, Windows updates and/or custom script, sysprep, register as a new (versioned) image       |
| `az-ps-copy-azure-local-image.ps1`   | Replicate an image to another storage path on the same cluster (file copy for gallery images, re-download for marketplace)      |
| `az-ps-get-azure-local-images.ps1`   | Inventory of all registered images (type, OS, state, storage path, source) with optional CSV export                             |
| `az-ps-remove-azure-local-image.ps1` | Delete one or more images with VM-reference safety check, typed confirmation and optional VHDX file cleanup                     |

### VM operations

| Script                                       | Description                                                                                         |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `az-ps-deploy-azure-local-vm-from-image.ps1` | Deploy a new Arc VM from a registered image (NIC creation, Secure Boot + vTPM, optional WinRM wait) |
| `az-ps-start-azure-local-vm.ps1`             | Start one or more VMs (batch-capable, skips already running VMs)                                    |
| `az-ps-stop-azure-local-vm.ps1`              | Stop one or more VMs (batch-capable, skips already stopped VMs)                                     |
| `az-ps-restart-azure-local-vm.ps1`           | Restart one or more running VMs (batch-capable)                                                     |
| `az-ps-get-azure-local-vm-inventory.ps1`     | Inventory of all Arc VMs (power state, sizing, IPs, network, image, disks) with optional CSV export |
| `az-ps-resize-azure-local-vm.ps1`            | Change vCPU and/or memory of a VM (stops a running VM first, optional automatic restart)            |
| `az-ps-add-azure-local-vm-data-disk.ps1`     | Create a virtual hard disk (dynamic or fixed) and attach it to a VM as data disk                    |
| `az-ps-remove-azure-local-vm.ps1`            | Delete a VM incl. Arc machine and OS disk, its NICs (optional keep) and optionally its data disks   |

### Infrastructure

| Script                                         | Description                                                                       |
| ---------------------------------------------- | --------------------------------------------------------------------------------- |
| `az-ps-create-azure-local-logical-network.ps1` | Create a logical network (static IP pool with gateway/DNS or DHCP) on the cluster |
| `az-ps-create-azure-local-storage-path.ps1`    | Register a storage path object pointing to a CSV directory for VM/image placement |

### Azure Virtual Desktop on Azure Local

| Script                               | Description                                                                                                                       |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------- |
| `az-ps-create-avd-control-plane.ps1` | Create the AVD control plane: host pool, desktop application group, workspace and optional user/group assignments (idempotent)    |
| `az-ps-deploy-avd-session-hosts.ps1` | Deploy Arc VMs from an image, domain-join them, onboard to Azure Arc and register them as session hosts (AVD agent + boot loader) |

The session host script needs WinRM (TCP 5985) reachability to the VM IPs, so
run it on a cluster node or a management machine on the same network (this
matches the XOAP Scripted Actions scenario). Guest-side tuning (FSLogix,
RDP Shortpath) is done with
`powershell/windows-server/ps-configure-avd-session-host.ps1`, and golden
images can be built with
`powershell/windows-server/ps-build-hyperv-golden-image.ps1`.

## Run location

| Runs anywhere with an Azure context                                                                                                                                                           | Must run ON a cluster node (Hyper-V + CSV access)                                                                                                |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| create-image, get-images, deploy-vm-from-image, start/stop/restart, vm-inventory, resize, add-data-disk, remove-vm, remove-image (control plane), create-logical-network, create-storage-path | deploy-azure-local-image, update-azure-local-image (capture phase), copy-azure-local-image (gallery images), remove-image with `-DeleteVhdxFile` |

## Usage Examples

### Download a marketplace image to the cluster

```powershell
.\az-ps-create-azure-local-image.ps1 `
    -ImageName "win11-23h2-avd" `
    -Urn "microsoftwindowsdesktop:windows-11:win11-23h2-avd:22631.3155.240229"
```

### Register a golden VHDX from cluster storage

```powershell
.\az-ps-create-azure-local-image.ps1 `
    -ImageName "win11-golden" `
    -VhdxPath "C:\ClusterStorage\UserStorage_2\Images\win11-golden.vhdx"
```

### Deploy a VM from an image (LocalBox defaults)

```powershell
$creds = Get-Credential
.\az-ps-deploy-azure-local-vm-from-image.ps1 `
    -VmName "avd-host-01" `
    -VmImageName "win11-23h2-avd" `
    -VmVcpu 4 `
    -VmMemoryGB 8 `
    -LocalAdminCreds $creds `
    -WaitForWinRM
```

### Patch a golden image with the latest Windows updates

```powershell
$creds = Get-Credential
.\az-ps-update-azure-local-image.ps1 `
    -SourceImageName "win11-23h2-avd" `
    -LocalAdminCreds $creds `
    -RunWindowsUpdate `
    -RemoveBuilderVm
```

### Replicate an image to the second cluster volume

```powershell
.\az-ps-copy-azure-local-image.ps1 -SourceImageName "win11-23h2-avd"
```

### Batch start / stop VMs

```powershell
.\az-ps-start-azure-local-vm.ps1 -VmNames "avd-host-01", "avd-host-02"
.\az-ps-stop-azure-local-vm.ps1 -VmNames "avd-host-01", "avd-host-02"
```

### Create a dedicated workload network

```powershell
.\az-ps-create-azure-local-logical-network.ps1
```

### Deploy a full AVD environment on Azure Local

```powershell
# 1) Control plane: host pool + desktop app group + workspace + user assignment
.\az-ps-create-avd-control-plane.ps1 `
    -HostPoolName "hp-azlocal-01" `
    -AssignGroupObjectIds @("11111111-2222-3333-4444-555555555555")

# 2) Session hosts: deploy VMs, domain join, Arc onboarding, AVD agent
.\az-ps-deploy-avd-session-hosts.ps1 `
    -HostPoolName "hp-azlocal-01" `
    -NamePrefix "avd-sh" `
    -SessionHostCount 2 `
    -VmImageName "win11-23h2-avd" `
    -LocalAdminPassword "P@ssw0rd-local" `
    -DomainFqdn "corp.contoso.com" `
    -DomainJoinUser "CORP\svc-domainjoin" `
    -DomainJoinPassword "P@ssw0rd-join" `
    -ArcServicePrincipalId "<appId>" `
    -ArcServicePrincipalSecret "<secret>" `
    -ArcTenantId "<tenantId>" `
    -UpdateTrustedHosts

# 3) Inside each session host: FSLogix profiles + RDP Shortpath
# (run as a scripted action on the VM)
# ..\..\powershell\windows-server\ps-configure-avd-session-host.ps1 `
#     -ProfileSharePath "\\fs01.corp.contoso.com\avd-profiles" `
#     -EnableRdpShortpath -EnableTimeZoneRedirection -Restart
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
- [Az.StackHCIVM module reference](https://learn.microsoft.com/en-us/powershell/module/az.stackhcivm/)
- [Create Azure Local VM images](https://learn.microsoft.com/en-us/azure/azure-local/manage/virtual-machine-image-azure-marketplace)
- [Manage Azure Local Arc VMs](https://learn.microsoft.com/en-us/azure/azure-local/manage/manage-arc-virtual-machines)
- [Azure Virtual Desktop on Azure Local](https://learn.microsoft.com/en-us/azure/virtual-desktop/azure-local-overview)
- [Add session hosts to a host pool](https://learn.microsoft.com/en-us/azure/virtual-desktop/add-session-hosts-host-pool)
- [Azure Arc Jumpstart LocalBox](https://github.com/microsoft/azure_arc/tree/main/azure_jumpstart_hcibox)
