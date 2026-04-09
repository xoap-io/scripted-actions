# Contributing to Scripted Actions

Thank you for contributing! This guide covers everything you need to add or
improve scripts in this repository.

## Prerequisites

Install the required tools before making any changes:

```bash
# Python tooling
pip install pre-commit

# Install the git hooks
pre-commit install
pre-commit install --hook-type commit-msg
```

PowerShell-specific hooks also require:

```powershell
# PowerShell 7+ (pwsh) must be on PATH
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

## Commit Message Format

All commits must follow the
[Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>: <short description>

Examples:
feat: add az-cli-create-aks-cluster script
fix: correct parameter validation in aws-cli-create-vpc
docs: update azure-cli/network README
chore: rename stack scripts to kebab-case
```

Accepted types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`.
Direct commits to `main` or `master` are blocked — always work on a branch.

## Adding a New Script

### 1. Choose the right directory

Scripts live under `{provider}-{interface}/{service}/`. See the directory
table in [CLAUDE.md](CLAUDE.md) or [README.md](README.md) for the full
mapping.

### 2. Name the file correctly

```
{provider}-{interface}-{action}-{resource}.ps1
```

| Pattern          | Example                             |
| ---------------- | ----------------------------------- |
| AWS CLI          | `aws-cli-create-security-group.ps1` |
| Azure CLI        | `az-cli-create-aks-cluster.ps1`     |
| Azure PowerShell | `az-ps-create-vm-snapshot.ps1`      |
| Google Cloud CLI | `gce-cli-create-gke-cluster.ps1`    |
| MS Graph         | `msgraph-create-entra-user.ps1`     |
| Bicep            | `bicep-deploy-windows-vm.ps1`       |
| Windows Server   | `ps-configure-windows-update.ps1`   |

### 3. Use the standard script structure

Copy `templates/template.ps1` as your starting point. Every script must have:

- Complete comment block (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`,
  `.EXAMPLE`, `.NOTES`, `.LINK`, `.COMPONENT`)
- Full XOAP disclaimer in `.NOTES`
- `[CmdletBinding()]` and a `param()` block
- Every `[Parameter()]` must include `HelpMessage = "..."`
- `$ErrorActionPreference = 'Stop'`
- `try / catch / finally` structure
- Emoji-prefixed coloured `Write-Host` output (see [CLAUDE.md](CLAUDE.md))

### 4. Use parameter splatting for complex commands

When a command takes more than 4-5 arguments, use splatting (see
`templates/splatting.ps1`):

```powershell
$params = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroupName
    Location          = $Location
}
New-AzSomething @params
```

### 5. Update the directory README

Every directory that contains scripts must have a `README.md`. If the script
goes into an existing directory, add a row for it in the directory's table.
If it goes into a new directory, create `README.md` before committing — the
`check-readme-exists` pre-commit hook will block the commit otherwise.

### 6. Run pre-commit before pushing

```bash
pre-commit run --all-files
```

Fix any warnings reported by PSScriptAnalyzer or prettier before opening a PR.

## Script Standards Reference

### Validation patterns

```powershell
# AWS resource IDs
[ValidatePattern('^i-[a-f0-9]{8,17}$')]       # EC2 instance
[ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]      # Security group
[ValidatePattern('^vpc-[a-f0-9]{8,17}$')]      # VPC
[ValidatePattern('^[a-z]{2}-[a-z]+-\d$')]      # AWS region

# Azure
[ValidateLength(1, 90)]
[ValidatePattern('^[a-zA-Z0-9._()-]+$')]       # Resource group name

# GCP
[ValidatePattern('^[a-z][a-z0-9-]{4,28}[a-z0-9]$')]  # Project ID
[ValidatePattern('^[a-z]+-[a-z]+\d+-[a-z]$')]          # Zone

# GUID (Azure Object IDs)
[ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-' +
                 '[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
```

### Common gotcha — scope qualifier in strings

In double-quoted strings, `$var:` is parsed as a PowerShell scope qualifier.
Always wrap variable names followed by `:` in a subexpression:

```powershell
# WRONG — parser error
"Failed: $zone: $($_.Exception.Message)"

# CORRECT
"Failed: $($zone): $($_.Exception.Message)"
```

### MS Graph scripts

- Do **not** call `Connect-MgGraph` — authentication is pre-established by XOAP
- Use `Invoke-MgGraphRequest` with `$GraphBase = 'https://graph.microsoft.com/v1.0'`

### Bicep scripts

- Write the inline Bicep template to a temp `.bicep` file in the script body
- Call `az deployment group create --template-file $tempFile`
- Clean up the temp file in the `finally` block

## Pull Request Checklist

Before opening a PR, confirm:

- [ ] Script follows the naming convention
- [ ] Comment block is complete (all sections filled in)
- [ ] XOAP disclaimer is present in `.NOTES`
- [ ] All parameters have `HelpMessage`
- [ ] `try / catch / finally` is in place
- [ ] The directory README lists the new script
- [ ] `pre-commit run --all-files` passes with no errors
