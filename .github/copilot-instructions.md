# Copilot AI Agent Instructions for `scripted-actions`

## Project Overview

- This repository contains a large collection of automation scripts for AWS and Azure, organized by provider, service, and interface (CLI/PowerShell).
- Scripts are grouped in folders such as `aws-cli/`, `aws-ps/`, `azure-cli/`, `azure-ps/`, and further by service (e.g., `ec2/`, `workspaces/`, `network/`).
- The main goal is to provide ready-to-use, modular scripts for common cloud automation tasks, not a unified application or library.

## Key Patterns & Conventions

- **Parameter Validation:** Scripts use PowerShell `[CmdletBinding()]` and `param()` blocks with `[ValidateSet]` and `[ValidatePattern]` for robust input validation (e.g., AWS resource IDs, instance types, regions).
- **Error Handling:** `$ErrorActionPreference = 'Stop'` is set in all scripts for strict error handling. Try/catch blocks are used in modernized scripts.
- **Output:** Scripts generally print success/failure messages and relevant AWS/Azure output, but avoid returning objects for further scripting unless explicitly needed.
- **Idempotency:** Scripts are designed to be safe to run multiple times, but users are expected to check for resource existence as needed.
- **No External State:** Scripts do not maintain state between runs. All configuration is via parameters or environment (e.g., AWS CLI/Azure CLI profiles).
- **Templates:** The `templates/` folder contains starter PowerShell script templates for new automation tasks.

## Developer Workflows

- **No Build Step:** Scripts are run directly in PowerShell or via CLI. There is no build or test harness.
- **Testing:** Manual testing is expected. There are no automated tests or CI workflows in this repo.
- **Adding Scripts:** New scripts should follow the parameter validation and error handling patterns found in the most recently updated scripts (see `aws-ps/`, `aws-cli/`, etc.).
- **Documentation:** Each script should have a PowerShell comment block with `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, and `.EXAMPLE` sections.

## Integration & Dependencies

- **AWS:** Scripts use either AWS CLI or AWS.Tools PowerShell modules. Ensure the correct tool is installed and configured.
- **Azure:** Scripts use either Azure CLI or Az PowerShell modules. See the `Readme.md` for links to installation and authentication guides.
- **No Cross-Script Imports:** Scripts are standalone and do not import or depend on each other.

## Examples

- See `aws-ps/ec2/aws-ps-create-ec2-instance.ps1` for a modern parameterized EC2 creation script with validation.
- See `aws-ps/appstream/appstream-quickstart.ps1` for a parameterized quickstart with region and CIDR validation.
- See `aws-cli/ec2/aws-cli-create-ec2-instance.ps1` for a CLI-based approach with similar validation patterns.

## Special Notes

- **Do not add build/test automation unless discussed with maintainers.**
- **Do not assume a unified application structure; treat each script as a standalone automation unit.**
- **Always update parameter validation and error handling to match the latest patterns.**

---

For more details, see `Readme.md` and the `templates/` folder.
