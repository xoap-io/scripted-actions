# Azure CLI Automation Scripts

This directory contains PowerShell scripts that automate Azure operations using
the Azure CLI. All scripts are designed to be standalone, modular, and follow
consistent patterns for parameter validation and error handling.

## Prerequisites

- **Azure CLI**: Install from [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/install-azure-cli)
- **PowerShell 5.1+**: Windows PowerShell or PowerShell Core
- **Azure Subscription**: Valid Azure subscription with appropriate permissions

## Authentication

Scripts authenticate using Azure CLI authentication:

```bash
# Interactive login
az login

# Service principal login
az login --service-principal -u <app-id> -p <password> --tenant <tenant-id>

# Device code flow (for restricted environments)
az login --use-device-code
```

## Directory Structure

| Folder | Description | Service Focus |
|--------|-------------|---------------|
| [`avd/`](./avd/) | Azure Virtual Desktop | Virtual desktop infrastructure |
| [`network/`](./network/) | Virtual networking | VNets, subnets, NSGs, load balancers |
| [`resource-manager/`](./resource-manager/) | Resource management | Resource groups, templates, deployments |
| [`security/`](./security/) | Security and identity | Key Vault, managed identities, RBAC |
| [`storage/`](./storage/) | Storage services | Storage accounts, blobs, file shares |
| [`vms/`](./vms/) | Virtual machines | VM creation, management, extensions |
| [`xoap/`](./xoap/) | XOAP-specific integrations | Custom automation workflows |

## Common Usage Patterns

### Azure CLI Verification

Scripts verify Azure CLI installation and authentication:

```powershell
# Check Azure CLI installation
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Azure CLI is not installed or not in PATH"
}

# Verify Azure authentication
$azAccount = az account show 2>$null | ConvertFrom-Json
if (-not $azAccount) {
    throw "Not logged into Azure. Run 'az login' first."
}
```

### Parameter Validation

All scripts use PowerShell validation:

```powershell
[ValidateSet("eastus", "westus2", "westeurope")]
[string]$Location

[ValidatePattern('^[a-zA-Z0-9-]{3,24}$')]
[string]$ResourceGroupName

[ValidateRange(1, 1000)]
[int]$VmCount
```

### Error Handling

Scripts implement comprehensive error handling:

```powershell
$ErrorActionPreference = 'Stop'
try {
    $result = az vm create --name $VmName --resource-group $ResourceGroupName `
              --image $ImageName --location $Location --output json | ConvertFrom-Json
    
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI command failed with exit code $LASTEXITCODE"
    }
}
catch {
    Write-Error "Operation failed: $($_.Exception.Message)"
    exit 1
}
```

## Quick Start Examples

### Create Virtual Machine

```powershell
.\vms\azure-cli-create-vm.ps1 `
  -VmName "MyVM" `
  -ResourceGroupName "MyRG" `
  -Location "eastus" `
  -AdminUsername "azureuser"
```

### Create Virtual Network

```powershell
.\network\azure-cli-create-vnet.ps1 `
  -VnetName "MyVNet" `
  -ResourceGroupName "MyRG" `
  -Location "eastus" `
  -AddressPrefix "10.0.0.0/16"
```

### Deploy AVD Environment

```powershell
.\avd\azure-cli-create-avd-hostpool.ps1 `
  -HostPoolName "MyHostPool" `
  -ResourceGroupName "MyRG" `
  -Location "eastus" `
  -HostPoolType "Pooled"
```

## Security Considerations

1. **Authentication**: Use service principals for automation scenarios
1. **RBAC**: Ensure minimal required permissions for operations
1. **Resource Tagging**: Apply consistent tags for governance and billing
1. **Key Management**: Use Azure Key Vault for sensitive data

## Best Practices

1. **Resource Groups**: Organize resources logically in resource groups
1. **Naming Conventions**: Follow Azure naming conventions and limits
1. **Location Consistency**: Keep related resources in the same region
1. **Cleanup**: Always clean up test resources to manage costs
1. **Documentation**: Include comprehensive help in all scripts

## Troubleshooting

### Common Issues

1. **Azure CLI Not Found**

   ```text
   az : The term 'az' is not recognized
   ```

   - Solution: Install Azure CLI and ensure it's in your PATH

1. **Not Authenticated**

   ```text
   Please run 'az login' to setup account
   ```

   - Solution: Run `az login` to authenticate

1. **Subscription Not Set**

   ```text
   No subscription found
   ```

   - Solution: Set subscription with `az account set --subscription <id>`

1. **Resource Already Exists**

   ```text
   Resource already exists
   ```

   - Solution: Use unique names or check existing resources

1. **Quota Exceeded**

   ```text
   Operation could not be completed as it results in exceeding quota
   ```

   - Solution: Check and request quota increases if needed

## Script Features

### Common Parameters

Most scripts support these standard parameters:

- `Location`: Azure region for resource deployment
- `ResourceGroupName`: Target resource group
- `SubscriptionId`: Specific subscription to use
- `Force`: Skip confirmation prompts
- `WhatIf`: Preview operations without executing
- `Tags`: Resource tags as hashtable

### Resource Management

- Automatic resource group creation if needed
- Consistent resource naming and tagging
- Cleanup procedures for failed deployments

### Output Formats

Scripts support multiple output formats:

- Console output with color coding
- JSON output for automation scenarios
- CSV export for reporting

## Azure CLI Extensions

Some scripts may require Azure CLI extensions:

```bash
# Install extensions as needed
az extension add --name azure-devops
az extension add --name desktopvirtualization
az extension add --name storage-preview
```

## Contributing

When adding new scripts:

1. Follow established parameter validation patterns
1. Include Azure CLI availability checks
1. Add comprehensive error handling
1. Include detailed help documentation with examples
1. Test across multiple Azure regions
1. Update this README with new script descriptions

## Resource Naming

Follow Azure naming conventions:

- Use lowercase letters, numbers, and hyphens
- Respect service-specific naming requirements
- Include environment indicators (dev, test, prod)
- Use consistent naming patterns across scripts

## Support

For issues or questions:

1. Check individual script help documentation
1. Review Azure CLI documentation for command reference
1. Consult Azure service documentation for limitations
1. Verify Azure permissions and quotas
