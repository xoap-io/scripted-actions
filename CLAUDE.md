# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

A collection of standalone PowerShell automation scripts for cloud providers (AWS, Azure, GCP, Nutanix, vSphere, XenServer) and Microsoft services (Intune, Entra ID via MS Graph). Scripts are designed for use with the **XOAP Scripted Actions** module but work standalone. There is no build step, no test harness, and no cross-script imports — each script is a self-contained automation unit.

## Directory Structure

| Directory | Tool | Provider |
|---|---|---|
| `aws-cli/` | AWS CLI | Amazon Web Services |
| `aws-ps/` | AWS.Tools modules | Amazon Web Services |
| `azure-cli/` | Azure CLI | Microsoft Azure |
| `azure-ps/` | Az PowerShell | Microsoft Azure |
| `gce-cli/` | gcloud CLI | Google Cloud |
| `gce-ps/` | Google Cloud PS | Google Cloud |
| `msgraph/` | Microsoft.Graph SDK | Entra ID / Intune |
| `nutanix-cli/` | Nutanix PS SDK | Nutanix |
| `vsphere-cli/` | VMware PowerCLI | VMware vSphere |
| `xenserver-cli/` | XenServer CLI | Citrix XenServer |
| `xoap-ops/` | Mixed | Cross-provider bulk ops |
| `powershell/` | PowerShell | Windows Server |
| `templates/` | — | Script templates |

Each provider directory is further organised by service (e.g. `aws-cli/ec2/`, `azure-cli/security/`).

## Script Naming Convention

```
{provider}-{interface}-{action}-{resource}.ps1
```

Examples: `aws-cli-create-ec2-instance.ps1`, `az-ps-create-linux-vm.ps1`, `msgraph-get-entra-users.ps1`

The `msgraph/` directory uses the pattern `msgraph-{action}-{service}.ps1`.

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
    Write-Host "❌ Failed: $($_.Exception.Message)" -ForegroundColor Red
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

## MS Graph Scripts (`msgraph/`)

Scripts in `msgraph/` assume authentication is pre-established by XOAP (no `Connect-MgGraph` call). They use `Invoke-MgGraphRequest` directly against the Graph REST API. No `ExportPath` parameter — CSV/JSON exports go to the current directory with a timestamped filename.

Subdirectories: `entra/` (users, groups, conditional access) and `intune/` (devices, apps, compliance, config policies).

## Pre-commit Hooks

Hooks run automatically on commit. Key enforced rules:
- **Conventional commits** required: `feat:`, `fix:`, `docs:`, `chore:`, etc.
- **No commits to `main` or `master`** directly
- **No UTF-8 BOM** in `.ps1` files (enforced by `check-powershell-bom` hook)
- **README.md must exist** in every directory that contains scripts (`check-readme-exists` hook)
- **LF line endings** (CRLF forbidden except in `.ps1` files)
- **Prettier** formats `.yaml` and `.md` files
- **shellcheck** runs on shell scripts (not `.ps1`)

Install hooks: `pre-commit install`

## Adding a New Script

1. Place it in the correct provider/service subdirectory.
2. Name it following `{provider}-{interface}-{action}-{resource}.ps1`.
3. Use the structure from `templates/template.ps1`.
4. Ensure the subdirectory has a `README.md` (the pre-commit hook will block the commit otherwise).
5. Use parameter splatting for commands with many arguments (see `templates/splatting.ps1`).
