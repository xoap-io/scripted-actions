# Introduction

This repository hosts scripts for the Scripted Actions area, which is part of
the [XOAP platform](https://xoap.io). They are provided as-is and are not
officially supported by XOAP. Use them at your own risk. Always test them in a
non-production environment before using them in production.

## Code of Conduct

This project has adopted this [Code of Conduct](CODE_OF_CONDUCT.md).

## Change log

A full list of changes in each version can be found in the [Releases](https://github.com/xoap-io/scripted-actions/releases).

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
  - [aws-cli/](aws-cli/) - AWS CLI-based scripts for EC2, networking, organizations, security, storage, and WorkSpaces
  - [aws-ps/](aws-ps/) - AWS PowerShell module scripts for AppStream, EC2, NICE DCV, security, and WorkSpaces
- **Azure** - Microsoft Azure automation (CLI & PowerShell)
  - [azure-cli/](azure-cli/) - Azure CLI scripts for AVD, networking, resource management, security, storage, and VMs
  - [azure-ps/](azure-ps/) - Azure PowerShell scripts for AVD, Azure Stack HCI, and security
- **Google Cloud** - GCP automation (CLI & PowerShell)
  - [gce-cli/](gce-cli/) - gcloud CLI scripts for Compute Engine VMs
  - [gce-ps/](gce-ps/) - Google Cloud PowerShell scripts for VM management

### Virtualization Platforms

- **Nutanix** - Nutanix AHV automation
  - [nutanix-cli/](nutanix-cli/) - Scripts for infrastructure, storage, and VM management via REST API
- **VMware vSphere** - vSphere automation with PowerCLI
  - [vsphere-cli/](vsphere-cli/) - Scripts for infrastructure, monitoring, and VM management
- **Citrix XenServer** - XenServer/XCP-ng automation
  - [xenserver-cli/](xenserver-cli/) - Scripts for infrastructure, network, storage, and VM operations

### Multi-Cloud Operations

- **XOAP Operations** - Cross-platform bulk operations
  - [xoap-ops/](xoap-ops/) - Multi-cloud VM termination, Azure image cleanup, and bulk management scripts

### Other Resources

- **PowerShell** - Windows Server management
  - [powershell/](powershell/) - Remote Desktop Services deployment and optimization scripts
- **Templates** - Script templates and patterns
  - [templates/](templates/) - Starter templates for creating new automation scripts

Each directory contains a comprehensive README.md with usage examples, best practices, and prerequisites specific to that platform or service.

## Latest Changes

### January 2026

- ✅ Added comprehensive README.md files to all script directories (37 total)
- ✅ Documented prerequisites, usage examples, and best practices for each platform
- ✅ Added XenServer/XCP-ng PowerShell scripts for VM, infrastructure, network, and storage management
- ✅ Enhanced pre-commit configuration with PowerShell-specific validation hooks
- ✅ Standardized documentation format across all cloud providers and platforms

## Templates

You can use the provided templates to create your scripts.
The templates are located in the `templates` folder.
