# Azure PowerShell Automation Scripts

This directory contains PowerShell scripts that automate Azure operations using
the Az PowerShell modules. Scripts include both organized subfolder scripts and
standalone automation scripts for common Azure tasks.

## Prerequisites

- **PowerShell 5.1+**: Windows PowerShell or PowerShell Core
- **Az PowerShell Modules**: Automatically installed by scripts when needed
- **Azure Subscription**: Valid Azure subscription with appropriate permissions

## Authentication

Scripts authenticate using Azure PowerShell authentication:

```powershell
# Interactive login
Connect-AzAccount

# Service principal login
$credential = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant "tenant-id"

# Managed identity (when running on Azure resources)
Connect-AzAccount -Identity
```

## Directory Structure

### Organized Scripts

| Folder | Description | Service Focus |
|--------|-------------|---------------|
| [`avd/`](./avd/) | Azure Virtual Desktop | AVD host pools, session hosts, scaling |

### Standalone Scripts

| Script | Description | Use Case |
|--------|-------------|----------|
| `az-ps-create-linux-vm.ps1` | Linux VM creation | Deploy Ubuntu/CentOS VMs |
| `az-ps-create-vm-scale-set.ps1` | VM Scale Set deployment | Auto-scaling VM groups |
| `az-ps-delete-running-vms.ps1` | Bulk VM cleanup | Cost management, testing cleanup |
| `az-ps-image-builder-windows-cleanup.ps1` | Image Builder cleanup | Remove temporary resources |
| `az-ps-install-nginx-linux-vm.ps1` | NGINX web server setup | Web server automation |
| `az-ps-install-webserver-windows.ps1` | IIS web server setup | Windows web server deployment |
| `Create-NewWindowsVm.ps1` | Windows VM creation | Standard Windows VM deployment |

### Work-in-Progress Scripts

| Script | Description | Status |
|--------|-------------|---------|
| `wip_az-ps-create-image-avd.ps1` | AVD image creation | Development |
| `wip_az-ps-image-builder-windows.ps1` | Windows image building | Development |

## Common Usage Patterns

### Module Installation

Scripts automatically install required Az modules:

```powershell
function Test-AzModule {
    param($ModuleName)
    
    if (-not (Get-Module -Name $ModuleName -ListAvailable)) {
        Write-Host "Installing $ModuleName..." -ForegroundColor Yellow
        Install-Module -Name $ModuleName -Force -AllowClobber -Scope CurrentUser
    }
    Import-Module $ModuleName -Force
}
```

### Parameter Validation

All scripts use comprehensive validation:

```powershell
[ValidateSet("East US", "West US 2", "West Europe")]
[string]$Location

[ValidatePattern('^[a-zA-Z0-9-]{3,24}$')]
[string]$ResourceGroupName

[ValidateSet("Standard_B2s", "Standard_D2s_v3", "Standard_F2s_v2")]
[string]$VMSize
```

### Error Handling

Scripts implement robust error handling:

```powershell
$ErrorActionPreference = 'Stop'
try {
    $vm = New-AzVM -ResourceGroupName $ResourceGroupName `
                   -Name $VMName `
                   -Location $Location `
                   -Size $VMSize
}
catch {
    Write-Error "VM creation failed: $($_.Exception.Message)"
    # Cleanup partial resources
    exit 1
}
```

## Quick Start Examples

### Create Linux VM

```powershell
.\az-ps-create-linux-vm.ps1 `
  -VMName "MyLinuxVM" `
  -ResourceGroupName "MyRG" `
  -Location "East US" `
  -AdminUsername "azureuser"
```

### Create Windows VM

```powershell
.\Create-NewWindowsVm.ps1 `
  -VMName "MyWindowsVM" `
  -ResourceGroupName "MyRG" `
  -Location "East US" `
  -AdminUsername "azureadmin"
```

### Create VM Scale Set

```powershell
.\az-ps-create-vm-scale-set.ps1 `
  -ScaleSetName "MyVMSS" `
  -ResourceGroupName "MyRG" `
  -Location "East US" `
  -InstanceCount 3
```

### Install Web Server

```powershell
# Install NGINX on Linux VM
.\az-ps-install-nginx-linux-vm.ps1 `
  -VMName "MyLinuxVM" `
  -ResourceGroupName "MyRG"

# Install IIS on Windows VM
.\az-ps-install-webserver-windows.ps1 `
  -VMName "MyWindowsVM" `
  -ResourceGroupName "MyRG"
```

### Cleanup Operations

```powershell
# Delete all running VMs in resource group
.\az-ps-delete-running-vms.ps1 `
  -ResourceGroupName "MyRG" `
  -Force
```

## Security Considerations

1. **Credential Management**: Use Azure PowerShell credential management
1. **RBAC**: Ensure minimal required permissions for operations
1. **Resource Tagging**: All resources are tagged for governance
1. **Secure Connections**: Scripts use secure communication protocols

## Best Practices

1. **Module Management**: Scripts handle Az module installation automatically
1. **Resource Organization**: Use consistent resource group strategies
1. **Naming Conventions**: Follow Azure naming best practices
1. **Cost Management**: Include cleanup scripts and resource monitoring
1. **Documentation**: Each script includes detailed help and examples

## Troubleshooting

### Common Issues

1. **Module Not Found**

   ```text
   Module 'Az.Compute' not found
   ```

   - Solution: Scripts auto-install modules or run `Install-Module Az.Compute`

1. **Not Authenticated**

   ```text
   Run Connect-AzAccount to login
   ```

   - Solution: Run `Connect-AzAccount` to authenticate

1. **Subscription Not Set**

   ```text
   No subscription found
   ```

   - Solution: Set subscription with `Set-AzContext -SubscriptionId <id>`

1. **Resource Name Conflict**

   ```text
   Resource name already exists
   ```

   - Solution: Use unique names or check existing resources

1. **Quota Exceeded**

   ```text
   Quota exceeded for resource type
   ```

   - Solution: Check quotas and request increases if needed

## Script Features

### Common Parameters

Most scripts support these standard parameters:

- `Location`: Azure region for resource deployment
- `ResourceGroupName`: Target resource group (created if doesn't exist)
- `SubscriptionId`: Specific subscription to use
- `Force`: Skip confirmation prompts
- `WhatIf`: Preview operations without executing
- `Tags`: Resource tags as hashtable

### Resource Management

- Automatic resource group creation
- Consistent resource naming and tagging
- Cleanup procedures for failed deployments
- Resource dependency management

### VM Management Features

- Custom script extensions for post-deployment configuration
- Network security group creation and configuration
- Public IP and DNS name assignment
- Disk encryption and backup configuration

### Automation Features

- Progress reporting with colored output
- Detailed logging of operations
- Performance metrics and timing
- Parallel processing where applicable

## Module Dependencies

Common Az modules used:

- `Az.Accounts`: Authentication and subscription management
- `Az.Compute`: Virtual machines and scale sets
- `Az.Network`: Virtual networks and security groups
- `Az.Storage`: Storage accounts and disk management
- `Az.Resources`: Resource groups and deployments
- `Az.KeyVault`: Key and secret management

## Contributing

When adding new scripts:

1. Follow the established parameter validation patterns
1. Include automatic module installation
1. Add comprehensive error handling with cleanup
1. Include detailed help documentation with examples
1. Test with multiple Azure regions and scenarios
1. Update this README with new script descriptions

## Performance Considerations

- Use parallel processing for bulk operations
- Implement progress reporting for long-running tasks
- Include timeout handling for network operations
- Optimize resource creation order for dependencies

## Support

For issues or questions:

1. Check the individual script help documentation
1. Review Azure PowerShell documentation
1. Consult Azure service-specific PowerShell cmdlet reference
1. Verify Azure credentials and permissions
