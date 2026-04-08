# Security Scripts

PowerShell scripts for managing Azure security services including Key Vault,
Network Security Groups, Application Security Groups, managed identities, RBAC,
and Microsoft Defender for Cloud using Azure CLI.

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)

## Available Scripts

| Script | Description |
| --- | --- |
| `az-cli-assign-role.ps1` | Assign an Azure RBAC role to a user, group, service principal, or managed identity |
| `az-cli-audit-key-vault.ps1` | Audit Key Vault access policies, network rules, and security configuration |
| `az-cli-audit-nsg-group.ps1` | Audit an NSG and export a JSON compliance report with rule analysis |
| `az-cli-backup-nsg-group.ps1` | Export the full configuration of an NSG to a timestamped JSON backup file |
| `az-cli-bulk-delete-nsg-rules.ps1` | Bulk delete NSG rules by name pattern, explicit list, or priority range |
| `az-cli-clone-nsg-group.ps1` | Clone all rules from a source NSG to a new destination NSG |
| `az-cli-create-asg.ps1` | Create an Application Security Group for network micro-segmentation |
| `az-cli-create-key-vault.ps1` | Create a Key Vault with soft delete, purge protection, and network restrictions |
| `az-cli-create-managed-identity.ps1` | Create a user-assigned managed identity with optional role assignments |
| `az-cli-create-nsg.ps1` | Create an NSG rule in an existing Network Security Group |
| `az-cli-create-nsg-group.ps1` | Create a Network Security Group with optional default rule profiles |
| `az-cli-delete-asg.ps1` | Delete an Application Security Group with dependency checking |
| `az-cli-delete-nsg-group.ps1` | Delete a Network Security Group with backup and safety checks |
| `az-cli-delete-nsg-rule.ps1` | Delete an NSG rule with optional backup and confirmation |
| `az-cli-disable-nsg-rule.ps1` | Disable an NSG rule by setting its access to Deny |
| `az-cli-export-nsg-rules.ps1` | Export all rules from an NSG to JSON or CSV |
| `az-cli-list-nsg-groups.ps1` | List NSGs in a subscription or resource group with optional export |
| `az-cli-list-nsg-rules.ps1` | List and analyze NSG rules with filtering and security gap detection |
| `az-cli-manage-firewall-rules.ps1` | Manage Azure Firewall application, network, and NAT rules |
| `az-cli-monitor-security-alerts.ps1` | Monitor Azure Security Center alerts and incidents with optional auto-response |
| `az-cli-restore-nsg-rule.ps1` | Restore an NSG rule from a JSON backup file |
| `az-cli-security-assessment.ps1` | Run a comprehensive security assessment using Microsoft Defender for Cloud |
| `az-cli-tag-nsg-rule.ps1` | Add or update tags on an NSG resource for compliance tracking |
| `az-cli-update-nsg-group.ps1` | Update tags on an NSG with optional compliance annotation |

## Usage Examples

### Create a Key Vault

```powershell
.\az-cli-create-key-vault.ps1 `
    -Name "kv-prod-secrets" `
    -ResourceGroup "rg-security" `
    -Location "eastus" `
    -EnablePurgeProtection `
    -EnableRbacAuthorization `
    -Tags "environment=production owner=security-team"
```

### Create an Application Security Group

```powershell
.\az-cli-create-asg.ps1 `
    -Name "web-servers" `
    -ResourceGroup "rg-web" `
    -Location "eastus" `
    -Description "Web server application security group"
```

### Create an NSG Rule

```powershell
.\az-cli-create-nsg.ps1 `
    -Name "AllowHTTPS" `
    -NsgName "web-nsg" `
    -Priority 100 `
    -ResourceGroup "rg-web" `
    -Access "Allow" `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -SourceAddressPrefixes "*" `
    -DestinationAddressPrefixes "10.0.1.0/24" `
    -DestinationPortRanges "443"
```

### Assign an RBAC Role

```powershell
.\az-cli-assign-role.ps1 `
    -Role "Contributor" `
    -Assignee "devteam@company.com" `
    -ResourceGroup "rg-production" `
    -Description "Production access for dev team"
```

### Audit an NSG

```powershell
.\az-cli-audit-nsg-group.ps1 `
    -NsgName "web-nsg" `
    -ResourceGroup "rg-web"
```

### Run a Security Assessment

```powershell
.\az-cli-security-assessment.ps1 `
    -Scope "Subscription" `
    -AssessmentType "Full" `
    -IncludeRecommendations `
    -GenerateReport
```

## Notes

- `az-cli-disable-nsg-rule.ps1` sets the rule access to Deny rather than
  removing the rule, preserving the rule configuration for easy re-enabling.
- `az-cli-backup-nsg-group.ps1` and `az-cli-restore-nsg-rule.ps1` work
  together to support safe NSG change management workflows.
- `az-cli-bulk-delete-nsg-rules.ps1` supports a `-Force` flag and a `-WhatIf`
  dry-run mode; always test with dry-run before bulk deletion.
- Key Vault names must be globally unique and between 3 and 24 characters.
