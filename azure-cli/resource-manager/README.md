# Azure CLI - Resource Manager Scripts

This directory contains PowerShell scripts for managing Azure resources using Azure Resource Manager (ARM) and Azure CLI.

## Prerequisites

- Azure CLI 2.50+ installed
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions
- Azure CLI logged in (`az login`)
- Contributor or Owner role on subscriptions/resource groups

## Available Scripts

### Resource Group Management

- Create, update, and delete resource groups
- List and filter resource groups
- Tag management
- Lock management

### Resource Operations

- List resources across subscriptions
- Resource tagging and organization
- Resource moving between groups
- Resource deletion and cleanup

### Deployment Management

- ARM template deployments
- Deployment validation
- Deployment history
- What-if operations

### Tag Management

- Apply tags to resources
- Update existing tags
- Tag-based queries
- Tag policies

### Policy and Governance

- Azure Policy assignment
- Policy compliance checking
- Management group operations
- Subscription management

## Usage Examples

### Create Resource Group

```powershell
# Create resource group with tags
az group create `
    --name myResourceGroup `
    --location eastus `
    --tags Environment=Production Team=DevOps
```

### Deploy ARM Template

```powershell
# Validate template
az deployment group validate `
    --resource-group myResourceGroup `
    --template-file template.json `
    --parameters parameters.json

# Deploy template
az deployment group create `
    --resource-group myResourceGroup `
    --template-file template.json `
    --parameters parameters.json `
    --name myDeployment
```

### List Resources with Tags

```powershell
# Find all resources with specific tag
az resource list --tag Environment=Production --output table
```

### Apply Tags to Resources

```powershell
# Tag a resource group
az group update `
    --name myResourceGroup `
    --tags CostCenter=12345 Project=WebApp
```

## Azure Resource Manager Best Practices

- **Organization**:

  - Use meaningful resource group names
  - Group related resources together
  - Implement consistent naming conventions
  - Use tags for cost allocation and organization

- **Deployment**:

  - Use ARM templates or Bicep for IaC
  - Validate templates before deployment
  - Use parameter files for different environments
  - Implement CI/CD for deployments

- **Security**:

  - Apply resource locks to prevent deletion
  - Use Azure Policy for compliance
  - Implement RBAC at appropriate scopes
  - Regular access reviews

- **Cost Management**:
  - Tag all resources for cost tracking
  - Use cost analysis tools
  - Implement budget alerts
  - Clean up unused resources

## Common Tagging Strategy

```yaml
Environment: Production | Development | Staging | Test
CostCenter: Department or team cost code
Owner: Email or team name
Project: Project name or code
ManagedBy: Terraform | ARM | Manual
Expiration: Date for temporary resources
```

## Resource Naming Convention Example

```
{resourceType}-{workload}-{environment}-{region}-{instance}

Examples:
rg-webapp-prod-eastus-001    (Resource Group)
vm-webserver-prod-eastus-001 (Virtual Machine)
st-data-prod-eastus-001      (Storage Account)
```

## Error Handling

Scripts include:

- Resource group existence checks
- Template validation
- Deployment status verification
- Quota limit checks
- Comprehensive error messages

## Related Documentation

- [Azure Resource Manager Documentation](https://docs.microsoft.com/azure/azure-resource-manager/)
- [ARM Template Reference](https://docs.microsoft.com/azure/templates/)
- [Azure CLI Reference - Resource](https://docs.microsoft.com/cli/azure/resource)
- [Azure Naming Conventions](https://docs.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/naming-and-tagging)

## Support

For issues or questions, please refer to the main repository documentation.
