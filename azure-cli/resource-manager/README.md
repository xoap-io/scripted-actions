# Resource Manager Scripts

PowerShell scripts for managing Azure resources, resource groups, deployments,
and governance using Azure CLI and Azure Resource Manager (ARM).

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)

## Available Scripts

| Script | Description |
| --- | --- |
| `az-cli-cost-analysis.ps1` | Analyze Azure resource costs and generate cost reports with optional CSV export |
| `az-cli-create-resource-group.ps1` | Create a new Azure Resource Group with optional tags and managed-by settings |
| `az-cli-delete-resource-group.ps1` | Delete an Azure Resource Group and all its resources |
| `az-cli-deploy-template.ps1` | Deploy an ARM template to a resource group |
| `az-cli-export-template.ps1` | Export an ARM template from an existing resource group or deployment |
| `az-cli-list-resource-groups.ps1` | List resource groups in a subscription with optional filtering |
| `az-cli-list-resources.ps1` | List resources in a subscription or resource group with filtering |
| `az-cli-manage-locks.ps1` | Create, list, and delete Azure resource locks at group or resource scope |
| `az-cli-manage-rbac.ps1` | Manage RBAC role assignments with support for bulk operations and reporting |
| `az-cli-monitor-health.ps1` | Monitor resource health, metrics, and availability |
| `az-cli-move-resources.ps1` | Move resources between resource groups or subscriptions |
| `az-cli-tag-resources.ps1` | Apply or update tags on resources and resource groups |

## Usage Examples

### Create a Resource Group

```powershell
.\az-cli-create-resource-group.ps1 `
    -ResourceGroup "rg-production" `
    -Location "East US" `
    -Tags '{"Environment":"Production","Owner":"TeamA"}'
```

### Deploy an ARM Template

```powershell
.\az-cli-deploy-template.ps1 `
    -ResourceGroup "rg-production" `
    -TemplateFile "./templates/main.json" `
    -ParametersFile "./templates/parameters.json" `
    -DeploymentName "deploy-2026-01"
```

### Manage Resource Locks

```powershell
.\az-cli-manage-locks.ps1 `
    -Operation "create" `
    -ResourceGroup "rg-production" `
    -LockName "prod-protection" `
    -LockType "CannotDelete" `
    -Notes "Protect production resources"
```

### Assign an RBAC Role

```powershell
.\az-cli-manage-rbac.ps1 `
    -Operation "assign" `
    -PrincipalId "12345678-1234-1234-1234-123456789abc" `
    -RoleName "Reader" `
    -ResourceGroup "rg-production"
```

### Run a Cost Analysis

```powershell
.\az-cli-cost-analysis.ps1 `
    -ResourceGroup "rg-production" `
    -TimeFrame "LastMonth" `
    -ExportToCsv "prod-costs.csv"
```

### Monitor Resource Health

```powershell
.\az-cli-monitor-health.ps1 `
    -ResourceGroup "rg-production" `
    -MonitoringMode "FullCheck" `
    -ExportReport "health-report.json"
```

## Notes

- Use `az-cli-manage-locks.ps1` with `-LockType CannotDelete` on production
  resource groups before making bulk changes.
- `az-cli-manage-rbac.ps1` supports a `-BulkOperation` flag with a CSV input
  file for managing multiple assignments at once.
- Cost analysis requires the `Microsoft.Consumption` resource provider to be
  registered on the subscription.
