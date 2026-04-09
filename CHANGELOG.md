# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Releases follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Full release history is available at the
[GitHub Releases](https://github.com/xoap-io/scripted-actions/releases) page.

---

## [Unreleased]

### Added

- `azure-cli/aks/` — AKS scripts: create cluster, scale node pool, get
  credentials
- `aws-cli/eks/` — EKS scripts: create cluster, create managed node group
- `gce-cli/gke/` — GKE scripts: create cluster, resize node pool
- `aws-cli/rds/` — RDS scripts: create DB instance, create manual snapshot
- `azure-cli/sql/` — Azure SQL scripts: create logical server, create database
- `gce-cli/sql/` — Cloud SQL scripts: create instance
- `aws-cli/lambda/` — Lambda scripts: create function, invoke function
- `azure-cli/functions/` — Azure Functions scripts: create Function App
- `gce-cli/functions/` — Cloud Functions scripts: deploy Cloud Function (gen2)
- `.github/workflows/powershell-lint.yml` — CI workflow for PSScriptAnalyzer
  and syntax checks on every PR touching `.ps1` files
- `.github/CODEOWNERS` — proper CODEOWNERS file (replaces CODEOWNERS.md)
- `.github/ISSUE_TEMPLATE/bug_report.yml` — script-repo-specific bug report
  template
- `.github/ISSUE_TEMPLATE/script_request.yml` — new script proposal template
- `CONTRIBUTING.md` — full contribution guide (pre-commit setup, naming
  conventions, script structure, PR checklist)

### Changed

- `azure-ps/avd/stack/` — all 35 scripts renamed from PascalCase
  (`New-AzWvdHostPool.ps1`) to kebab-case (`az-ps-create-avd-hostpool.ps1`)
  to match repository convention
- `azure-ps/avd/README.md` — updated script table to reflect new filenames
- `.github/dependabot.yml` — removed stale Terraform ecosystem entry
- `.github/ISSUE_TEMPLATE/config.yml` — updated contact link to XOAP platform
- `README.md` — added `msgraph/` to Repository Structure; updated `gce-cli/`,
  `aws-cli/`, `azure-cli/`, `powershell/` entries; expanded April 2026
  changelog section

### Removed

- `CODEOWNERS.md` — replaced by `.github/CODEOWNERS`
- `.github/ISSUE_TEMPLATE/Problem_with_resource.yml` — DSC-specific template
  not applicable to this repo
- `.github/ISSUE_TEMPLATE/Resource_proposal.yml` — DSC-specific template
- `.github/ISSUE_TEMPLATE/General.md` — replaced by structured templates
- `azure-cli/avd/az-cli-avd-hostpool-create-optimized.ps1` — empty stub
- `azure-cli/avd/az-cli-avd-hostpool-update-optimized.ps1` — empty stub
- `azure-cli/avd/az-cli-avd-workspace-update-optimized.ps1` — empty stub

---

## [1.0.0] — 2026-01-01

### Added

- Initial release of Scripted Actions repository
- Scripts for AWS (CLI and PowerShell), Azure (CLI, PowerShell, Bicep),
  Google Cloud (CLI and PowerShell), Microsoft 365 / Entra ID / Intune
  (MS Graph), Nutanix, VMware vSphere, and Citrix XenServer
- Pre-commit hooks for conventional commits, PSScriptAnalyzer,
  PowerShell syntax checking, UTF-8 BOM detection, and README enforcement
- GitHub Actions workflows for PR labelling, reviewer assignment,
  commit message validation, and semantic release tagging
- README.md files for all script directories
