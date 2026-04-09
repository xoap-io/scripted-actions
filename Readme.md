# Introduction

This repository hosts scripts for the Scripted Actions area, which is part of
the [XOAP platform](https://xoap.io). They are provided as-is and are not
officially supported by XOAP. Use them at your own risk. Always test them in a
non-production environment before using them in production.

## Code of Conduct

This project has adopted this [Code of Conduct](CODE_OF_CONDUCT.md).

## Change log

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes.
Full release artefacts are available at the
[GitHub Releases](https://github.com/xoap-io/scripted-actions/releases) page.

## Documentation

### Azure CLI & Bicep

Most of the available scripts are built to use a local Azure CLI configuration
file. Find more information here: [Azure CLI Configuration](https://docs.microsoft.com/en-us/cli/azure/azure-cli-configuration).

### Azure PowerShell

For Azure PowerShell-related scripts we suggest using the noninteractive
authentication with a service principal:
[Sign in to Azure PowerShell with a service principal](https://learn.microsoft.com/en-us/powershell/azure/authenticate-noninteractive?view=azps-11.4.0).

### AWS CLI

For AWS CLI-related scripts we suggest using the AWS CLI configuration file:
[Configuration and credential file settings](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html).

## Prerequisites

Depending on which scripts you want to use, you need to have the following
prerequisites installed:

### Azure CLI

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

### Azure PowerShell

- [Azure PowerShell](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)

### AWS CLI

- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

### AWS PowerShell

- [AWS Tools for PowerShell](https://aws.amazon.com/powershell/)

### Google Cloud SDK

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (includes gcloud CLI)
- [Google Cloud PowerShell](https://github.com/GoogleCloudPlatform/google-cloud-powershell)

### VMware PowerCLI

- [VMware PowerCLI](https://developer.vmware.com/powercli) - Install via `Install-Module -Name VMware.PowerCLI`

### XenServer PowerShell Module

- [XenServerPSModule](https://docs.citrix.com/en-us/citrix-hypervisor/sdk/) - Download from Citrix XenServer SDK

### Nutanix

- PowerShell with REST API capabilities (no specific module required)
- Nutanix Prism Central or Prism Element access

### Bicep

- [Bicep](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#azure-cli)

### ARM Templates

See Azure CLI & Azure PowerShell.

## Repository Structure

This repository contains automation scripts organized by cloud provider and platform:

### Cloud Providers

- **AWS** - Amazon Web Services automation (CLI & PowerShell)
  - [aws-cli/](aws-cli/) - AWS CLI-based scripts for EC2, EKS, Lambda,
    monitoring, networking, organizations, RDS, security, storage, and
    WorkSpaces
  - [aws-ps/](aws-ps/) - AWS PowerShell module scripts for AppStream,
    EC2, NICE DCV, security, and WorkSpaces
- **Azure** - Microsoft Azure automation (CLI, PowerShell & Bicep)
  - [azure-cli/](azure-cli/) - Azure CLI scripts for AKS, AVD, Functions,
    monitoring, networking, resource management, security, SQL, storage,
    and VMs
  - [azure-ps/](azure-ps/) - Azure PowerShell scripts for AVD,
    Azure Stack HCI, and security
  - [bicep/](bicep/) - Azure Bicep IaC scripts for declarative VM,
    networking, and AVD deployments
- **Google Cloud** - GCP automation (CLI & PowerShell)
  - [gce-cli/](gce-cli/) - gcloud CLI scripts for Compute Engine VMs,
    Cloud Functions, GKE, networking, Cloud Storage, and Cloud SQL
  - [gce-ps/](gce-ps/) - Google Cloud PowerShell scripts for VM management
- **Microsoft 365 / Entra ID / Intune** - Microsoft cloud identity and
  device management
  - [msgraph/](msgraph/) - Microsoft Graph API scripts for Entra ID
    (users, groups, roles, sign-in logs) and Intune (devices, apps,
    compliance and config policies)

### Virtualization Platforms

- **Nutanix** - Nutanix AHV automation
  - [nutanix-cli/](nutanix-cli/) - Scripts for infrastructure, storage,
    and VM management via Prism Central REST API
- **VMware vSphere** - vSphere automation with PowerCLI
  - [vsphere-cli/](vsphere-cli/) - Scripts for infrastructure, monitoring,
    and VM management
- **Citrix XenServer** - XenServer/XCP-ng automation
  - [xenserver-cli/](xenserver-cli/) - Scripts for infrastructure, network,
    storage, and VM operations

### Multi-Cloud Operations

- **XOAP Operations** - Cross-platform bulk operations
  - [xoap-ops/](xoap-ops/) - Multi-cloud VM termination, Azure image
    cleanup, and bulk management scripts

### Other Resources

- **PowerShell** - Windows Server management
  - [powershell/](powershell/) - Windows Server administration scripts
    including RDS, Windows Update, local user management, WinRM, and CIS
    hardening
- **Templates** - Script templates and patterns
  - [templates/](templates/) - Starter templates for creating new
    automation scripts

Each directory contains a comprehensive README.md with usage examples, best practices, and prerequisites specific to that platform or service.

## Latest Changes

### April 2026

- ✅ Added `bicep/` top-level directory with Azure Bicep IaC scripts
  (`vms/`, `networking/`, `avd/`)
- ✅ Added `gce-cli/network/` and `gce-cli/storage/` subdirectories
  with VPC, firewall, subnet, bucket, object, and disk scripts
- ✅ Added `aws-cli/monitoring/` with CloudWatch dashboards, alarms,
  Cost Explorer, and AWS Budgets scripts
- ✅ Added `azure-cli/monitoring/` with Log Analytics, Azure Monitor
  alerts, activity log, and diagnostic settings scripts
- ✅ Added `powershell/windows-server/` with Windows Update, local user
  management, WinRM configuration, and CIS hardening scripts
- ✅ Added `msgraph/entra/` scripts: create/update user, assign directory
  role, get sign-in logs, remove group member
- ✅ Added `msgraph/intune/` scripts: create compliance policy, retire
  device, get enrollment status, assign config policy
- ✅ Added `msgraph/msgraph-check-cis-benchmark.ps1` — checks and
  optionally remediates 12 CIS Microsoft 365 Foundations controls
- ✅ Rewrote `xoap-ops/` bulk-operation scripts with comprehensive
  logging, WhatIf/Force support, and post-operation verification
- ✅ Added `azure-cli/aks/`, `aws-cli/eks/`, `gce-cli/gke/` with
  Kubernetes cluster management scripts (create, scale, credentials)
- ✅ Added `aws-cli/rds/`, `azure-cli/sql/`, `gce-cli/sql/` with managed
  database scripts (create instance/server/database, create snapshot)
- ✅ Added `aws-cli/lambda/`, `azure-cli/functions/`, `gce-cli/functions/`
  with serverless/Functions scripts (create, invoke, deploy)
- ✅ Added CI workflow (`powershell-lint.yml`) to enforce PSScriptAnalyzer
  and syntax checks on every PR
- ✅ Added `CONTRIBUTING.md` with full contribution guide
- ✅ Added `CHANGELOG.md` with version history
- ✅ Fixed `CODEOWNERS` (was `.md` extension, now `.github/CODEOWNERS`)
- ✅ Replaced DSC-specific issue templates with script-repo-specific ones
- ✅ Renamed `azure-ps/avd/stack/` scripts to kebab-case convention
- ✅ README.md files added or updated for all new and existing directories
- ✅ CLAUDE.md updated to reflect all new directories, conventions, and
  provider-specific patterns

### January 2026

- ✅ Added comprehensive README.md files to all script directories (37 total)
- ✅ Documented prerequisites, usage examples, and best practices for each platform
- ✅ Added XenServer/XCP-ng PowerShell scripts for VM, infrastructure, network, and storage management
- ✅ Enhanced pre-commit configuration with PowerShell-specific validation hooks
- ✅ Standardized documentation format across all cloud providers and platforms

## Templates

You can use the provided templates to create your scripts.
The templates are located in the `templates` folder.

## Contributing

### Pre-commit Hooks

This repository uses [pre-commit](https://pre-commit.com) to enforce code quality
and consistency. All contributors must have pre-commit configured before making
changes.

#### Installation

```bash
# Install pre-commit
pip install pre-commit

# Install the hooks into your local clone
pre-commit install
pre-commit install --hook-type commit-msg
```

The `--hook-type commit-msg` flag is required to enable the conventional commit
message validation hook.

#### PowerShell-specific Prerequisites

The following must be installed for the PowerShell hooks to run:

- **PowerShell 7+** (`pwsh`) — required for syntax checking and PSScriptAnalyzer
- **PSScriptAnalyzer** — install once in PowerShell:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

#### What the Hooks Check

| Hook                        | What it does                                                                 |
| --------------------------- | ---------------------------------------------------------------------------- |
| `conventional-pre-commit`   | Enforces conventional commit message format (`feat:`, `fix:`, `docs:`, etc.) |
| `trailing-whitespace`       | Removes trailing whitespace                                                  |
| `end-of-file-fixer`         | Ensures files end with a newline                                             |
| `check-yaml` / `check-json` | Validates YAML and JSON syntax                                               |
| `detect-private-key`        | Blocks accidental credential commits                                         |
| `no-commit-to-branch`       | Prevents direct commits to `main` or `master`                                |
| `prettier`                  | Formats Markdown and YAML files                                              |
| `shellcheck`                | Lints shell scripts                                                          |
| `codespell`                 | Catches common typos in code and comments                                    |
| `powershell-syntax-check`   | Validates `.ps1` syntax using PowerShell's own parser                        |
| `psscriptanalyzer`          | Lints `.ps1` files for warnings and errors                                   |
| `check-powershell-bom`      | Ensures `.ps1` files have no UTF-8 BOM                                       |
| `check-readme-exists`       | Ensures every script directory has a `README.md`                             |

#### Running Hooks Manually

```bash
# Run all hooks against all files
pre-commit run --all-files

# Run a specific hook
pre-commit run psscriptanalyzer --all-files
pre-commit run powershell-syntax-check --all-files
```
