# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A collection of standalone PowerShell automation scripts for cloud providers
(AWS, Azure, GCP, Nutanix, vSphere, XenServer) and Microsoft services (Intune,
Entra ID via MS Graph). Scripts are designed for use with the **XOAP Scripted
Actions** module but work standalone. There is no build step, no test harness,
and no cross-script imports — each script is a self-contained automation unit.

## Directory Structure

| Directory        | Tool                  | Provider                |
| ---------------- | --------------------- | ----------------------- |
| `aws-cli/`       | AWS CLI v2            | Amazon Web Services     |
| `aws-ps/`        | AWS.Tools modules     | Amazon Web Services     |
| `azure-cli/`     | Azure CLI             | Microsoft Azure         |
| `azure-ps/`      | Az PowerShell         | Microsoft Azure         |
| `bicep/`         | Azure CLI + Bicep     | Microsoft Azure (IaC)   |
| `gce-cli/`       | gcloud CLI            | Google Cloud            |
| `gce-ps/`        | Google Cloud PS       | Google Cloud            |
| `msgraph/`       | Microsoft.Graph SDK   | Entra ID / Intune       |
| `nutanix-cli/`   | Nutanix REST API (PS) | Nutanix                 |
| `vsphere-cli/`   | VMware PowerCLI       | VMware vSphere          |
| `xenserver-cli/` | XenServer PS SDK      | Citrix XenServer        |
| `xoap-ops/`      | Mixed                 | Cross-provider bulk ops |
| `powershell/`    | PowerShell            | Windows Server          |
| `templates/`     | —                     | Script templates        |

Each provider directory is further organised by service area:

- `aws-cli/` → `ec2/`, `network/`, `organizations/`, `security/`, `storage/`,
  `workspaces/`, `monitoring/`, `xoap/`
- `aws-ps/` → `ec2/`, `appstream/`, `nice-dcv/`, `security/`, `workspaces/`
- `azure-cli/` → `avd/`, `network/`, `resource-manager/`, `security/`,
  `storage/`, `vms/`, `monitoring/`, `xoap/`
- `azure-ps/` → root scripts, `AzStackHCI/`, `avd/`, `security/`
- `bicep/` → `vms/`, `networking/`, `avd/`
- `gce-cli/` → `vms/`, `network/`, `storage/`
- `gce-ps/` → `vms/`
- `msgraph/` → `entra/`, `intune/`
- `nutanix-cli/` → `infrastructure/`, `storage/`, `vms/`
- `vsphere-cli/` → `infrastructure/`, `monitoring/`, `vms/`
- `xenserver-cli/` → `infrastructure/`, `network/`, `storage/`, `vms/`
- `powershell/` → root scripts, `windows-server/`

## Script Naming Convention

```
{provider}-{interface}-{action}-{resource}.ps1
```

Examples: `aws-cli-create-ec2-instance.ps1`, `az-ps-create-linux-vm.ps1`,
`msgraph-get-entra-users.ps1`

The `msgraph/` directory uses `msgraph-{action}-{service}.ps1`.
The `bicep/` directory uses `bicep-deploy-{resource}.ps1`.
The `powershell/windows-server/` directory uses `ps-{action}-{topic}.ps1`.

## Script Structure — Required Elements

Every script must follow this structure exactly (see `templates/template.ps1`):

```powershell
<#
.SYNOPSIS
    One-line description.

.DESCRIPTION
    Full description. Include the underlying CLI/API command used.

.PARAMETER ParamName
    Description of parameter.

.EXAMPLE
    .\script-name.ps1 -Param "value"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: <tool name>

.LINK
    <official docs URL>

.COMPONENT
    <Tool/Platform>
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "...")]
    [ValidateNotNullOrEmpty()]
    [string]$ParamName
)

$ErrorActionPreference = 'Stop'

try {
    # main logic
}
catch {
    Write-Host "`n❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
```

## Parameter Validation Patterns

Use these exact patterns for resource identifiers:

```powershell
# AWS resource IDs
[ValidatePattern('^ami-[a-zA-Z0-9]{8,}$')]         # AMI
[ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]           # Security Group
[ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]       # Subnet
[ValidatePattern('^i-[a-f0-9]{8,17}$')]             # Instance
[ValidatePattern('^vpc-[a-f0-9]{8,17}$')]           # VPC
[ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]           # Region

# Azure
[ValidateLength(1, 90)]
[ValidatePattern('^[a-zA-Z0-9._()-]+$')]            # Resource Group name

# GUIDs (Azure Object IDs, Graph IDs)
[ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]

# CIDR
[ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]

# GCP
[ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]  # Project ID
[ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]          # Zone
[ValidatePattern('^[a-z]+-[a-z]+\d+$')]                # Region
```

## Output Conventions

Use coloured, emoji-prefixed output consistently:

```powershell
Write-Host "🚀 Starting operation"         -ForegroundColor Green
Write-Host "🔍 Validating..."              -ForegroundColor Cyan
Write-Host "🔧 Performing action..."       -ForegroundColor Cyan
Write-Host "✅ Success message"            -ForegroundColor Green
Write-Host "⚠️  Warning message"           -ForegroundColor Yellow
Write-Host "ℹ️  Info message"              -ForegroundColor Yellow
Write-Host "❌ Error message"              -ForegroundColor Red
Write-Host "🏁 Script execution completed" -ForegroundColor Green
Write-Host "💡 Next Steps:"               -ForegroundColor Yellow
Write-Host "📊 Summary:"                  -ForegroundColor Blue
```

## Provider-Specific Conventions

### MS Graph Scripts (`msgraph/`)

- No `Connect-MgGraph` — authentication is pre-established by XOAP
- Use `Invoke-MgGraphRequest` directly with `$GraphBase = 'https://graph.microsoft.com/v1.0'`
- No `ExportPath` parameter — CSV/JSON exports go to the current directory with
  a timestamped filename
- `entra/` covers users, groups, roles, conditional access, sign-in logs
- `intune/` covers devices, apps, compliance policies, config policies, enrollment

### Bicep Scripts (`bicep/`)

- Scripts write an inline Bicep template to a temp `.bicep` file, call
  `az deployment group create --template-file`, then clean up in `finally`
- Check for `az bicep` availability at script start
- `Requires: Azure CLI with Bicep (az bicep install)` in `.NOTES`

### Nutanix Scripts (`nutanix-cli/`)

- Use `Invoke-RestMethod` with Basic auth header against Prism Central REST
  API v3
- Base URL: `https://$PrismCentralHost:9440/api/nutanix/v3`
- Add `-SkipCertificateCheck` for PS7+; use inline `ICertificatePolicy` type
  for PS5.1 self-signed cert bypass

### xoap-ops Scripts

- Bulk operations across cloud providers (terminate/stop all VMs in an account)
- Always include: `Write-Log` function writing to a timestamped log file AND
  console, `WhatIf` switch, `Force` switch (skip confirmation), post-operation
  verification (re-query and confirm no VMs remain running), `'YES'` typed
  confirmation unless `-Force`

### PowerShell Scope Variable Gotcha

In double-quoted strings, `$var:` is parsed as a scope qualifier (like `$env:`).
Always use `$($var):` to avoid parser errors:

```powershell
# WRONG — parser error
"Failed to delete $diskId: $($_.Exception.Message)"

# CORRECT
"Failed to delete $($diskId): $($_.Exception.Message)"
```

## Pre-commit Hooks

Install: `pre-commit install && pre-commit install --hook-type commit-msg`

Key enforced rules:

- **Conventional commits** required: `feat:`, `fix:`, `docs:`, `chore:`, etc.
- **No commits to `main` or `master`** directly
- **No UTF-8 BOM** in `.ps1` files (`check-powershell-bom` hook)
- **README.md must exist** in every directory containing scripts
  (`check-readme-exists` hook)
- **Prettier** formats `.yaml` and `.md` files (80-char line limit in prose;
  tables are exempt via `"MD013": { "line_length": 80, "tables": false }`)
- **PSScriptAnalyzer** lints `.ps1` at Warning/Error severity
- **powershell-syntax-check** validates `.ps1` syntax via `pwsh` parser
- **codespell** catches common typos

Run manually: `pre-commit run --all-files`

## Adding a New Script

1. Place it in the correct provider/service subdirectory.
2. Name it following `{provider}-{interface}-{action}-{resource}.ps1`.
3. Use the structure from `templates/template.ps1`.
4. Every `[Parameter()]` must include `HelpMessage = "..."`.
5. Ensure the subdirectory has a `README.md` with the new script listed
   (pre-commit hook blocks commits otherwise).
6. Use parameter splatting for commands with many arguments
   (see `templates/splatting.ps1`).
7. `.COMPONENT` must match the tool/platform (e.g. `AWS CLI EC2`,
   `Azure PowerShell Virtual Machines`, `Microsoft Graph Entra ID`).
