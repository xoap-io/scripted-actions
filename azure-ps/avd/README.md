# Azure PowerShell - Azure Virtual Desktop (AVD)

This directory contains PowerShell scripts for managing Azure Virtual Desktop (AVD) environments using the Az PowerShell module.

## Prerequisites

- Azure PowerShell modules installed:
  - `Install-Module -Name Az`
  - `Install-Module -Name Az.DesktopVirtualization`
  - `Install-Module -Name Az.Compute`
  - `Install-Module -Name Az.Network`
  - `Install-Module -Name Az.KeyVault`
  - `Install-Module -Name Az.Storage`
- PowerShell 5.1 or later (PowerShell 7+ recommended)
- Azure subscription with appropriate permissions

## Subdirectories

### stack/

Contains scripts for deploying and managing complete AVD stack resources including:

- Host pools (`New-AzWvdHostPool`, `Update-AzWvdHostPool`, `Remove-AzWvdHostPool`)
- Application groups (`New-AzWvdApplicationGroup`, `Update-AzWvdApplicationGroup`, `Remove-AzWvdApplicationGroup`)
- Workspaces (`New-AzWvdWorkspace`, `Update-AzWvdWorkspace`, `Remove-AzWvdWorkspace`)
- Applications (`New-AzWvdApplication`, `Update-AzWvdApplication`, `Remove-AzWvdApplication`)
- MSIX packages (`New-AzWvdMsixPackage`, `Update-AzWvdMsixPackage`, `Remove-AzWvdMsixPackage`)
- Session hosts (`Update-AzWvdSessionHost`, `Remove-AzWvdSessionHost`)
- User sessions (`Remove-AzWvdUserSession`, `Send-AzWvdUserSessionMessage`)
- Registration info (`New-AzWvdRegistrationInfo`, `Remove-AzWvdRegistrationInfo`)
- Scaling plans (`Remove-AzWvdScalingPlan`, `Remove-AzWvdScalingPlanPersonalSchedule`, `Remove-AzWvdScalingPlanPooledSchedule`)
- Supporting Azure resources (Key Vault, Storage Account, Virtual Network, Resource Group)

### stack/_todo/

Work-in-progress scripts for additional AVD automation including scaling plan creation and scheduled deployment scenarios.

## Related Documentation

- [Azure Virtual Desktop documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Az.DesktopVirtualization module reference](https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/)
