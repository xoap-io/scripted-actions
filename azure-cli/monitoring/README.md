# Monitoring Scripts

PowerShell scripts for managing Azure Monitor resources including Log Analytics
workspaces, metric alert rules, activity log queries, and diagnostic settings
using Azure CLI.

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)

## Available Scripts

| Script                                      | Description                                                                                |
| ------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `az-cli-create-log-analytics-workspace.ps1` | Create a Log Analytics workspace with configurable SKU and retention period                |
| `az-cli-create-monitor-alert.ps1`           | Create a metric alert rule with configurable threshold, window, and action group           |
| `az-cli-get-activity-log.ps1`               | Query the Azure Activity Log with filters for resource group, caller, and status           |
| `az-cli-create-diagnostic-setting.ps1`      | Create a diagnostic setting to route resource logs and metrics to Log Analytics or Storage |

## Usage Examples

### Create a Log Analytics Workspace

```powershell
.\az-cli-create-log-analytics-workspace.ps1 `
    -ResourceGroupName "rg-monitoring" `
    -WorkspaceName "law-prod-01" `
    -Location "eastus" `
    -Sku "PerGB2018" `
    -RetentionDays 90
```

### Create a Metric Alert Rule

```powershell
.\az-cli-create-monitor-alert.ps1 `
    -ResourceGroupName "rg-monitoring" `
    -AlertName "high-cpu-alert" `
    -TargetResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vms/providers/Microsoft.Compute/virtualMachines/vm-prod-01" `
    -MetricName "Percentage CPU" `
    -Operator "GreaterThan" `
    -Threshold 90 `
    -Severity 1
```

### Query the Activity Log

```powershell
.\az-cli-get-activity-log.ps1 `
    -ResourceGroupName "rg-production" `
    -StartTime "7d" `
    -Status "Failed" `
    -OutputFormat "CSV"
```

### Create a Diagnostic Setting

```powershell
.\az-cli-create-diagnostic-setting.ps1 `
    -ResourceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-vms/providers/Microsoft.Compute/virtualMachines/vm-prod-01" `
    -SettingName "diag-vm-prod-01" `
    -WorkspaceId "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-prod-01" `
    -EnableAllLogs `
    -EnableAllMetrics
```

## Notes

- Log Analytics workspace names must be unique within a resource group and
  between 4 and 63 characters.
- Metric alert rules require the target resource to support Azure Monitor metrics.
  Check available metrics with `az monitor metrics list-definitions --resource <id>`.
- Activity log queries are limited to the last 90 days of data.
- Diagnostic settings require the target resource to support Azure Monitor
  diagnostic categories. Use `az monitor diagnostic-settings categories list`
  to view available categories.
- The `PerGB2018` SKU is the recommended tier for Log Analytics workspaces
  and charges per GB of data ingested.
