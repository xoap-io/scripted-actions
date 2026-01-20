# Azure PowerShell - AVD Stack Scripts

This directory contains PowerShell scripts for Azure Virtual Desktop stack deployment and management.

## Prerequisites

- Azure PowerShell modules installed:
  - `Install-Module -Name Az.DesktopVirtualization`
  - `Install-Module -Name Az.Compute`
  - `Install-Module -Name Az.Network`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions
- Existing Azure infrastructure (VNet, AD, etc.)

## Available Scripts

Scripts for deploying and managing complete AVD stacks including:

- Host pool provisioning
- Session host deployment
- Application group configuration
- Workspace setup
- User assignment automation
- Monitoring configuration

## Usage

These scripts typically deploy full AVD environments following infrastructure-as-code principles.

## Related Documentation

- [Azure Virtual Desktop Documentation](https://docs.microsoft.com/azure/virtual-desktop/)
- [Az.DesktopVirtualization Module](https://docs.microsoft.com/powershell/module/az.desktopvirtualization/)

## Support

For issues or questions, please refer to the main repository documentation.
