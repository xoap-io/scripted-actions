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

| Script                                                | Description                             |
| ----------------------------------------------------- | --------------------------------------- |
| `az-ps-create-avd-hostpool.ps1`                       | Create an AVD host pool                 |
| `az-ps-update-avd-hostpool.ps1`                       | Update an AVD host pool                 |
| `az-ps-remove-avd-hostpool.ps1`                       | Remove an AVD host pool                 |
| `az-ps-create-avd-application-group.ps1`              | Create an application group             |
| `az-ps-update-avd-application-group.ps1`              | Update an application group             |
| `az-ps-remove-avd-application-group.ps1`              | Remove an application group             |
| `az-ps-register-avd-application-group.ps1`            | Register application group to workspace |
| `az-ps-unregister-avd-application-group.ps1`          | Unregister application group            |
| `az-ps-create-avd-workspace.ps1`                      | Create an AVD workspace                 |
| `az-ps-update-avd-workspace.ps1`                      | Update an AVD workspace                 |
| `az-ps-remove-avd-workspace.ps1`                      | Remove an AVD workspace                 |
| `az-ps-create-avd-application.ps1`                    | Create a RemoteApp application          |
| `az-ps-update-avd-application.ps1`                    | Update a RemoteApp application          |
| `az-ps-remove-avd-application.ps1`                    | Remove a RemoteApp application          |
| `az-ps-create-avd-msix-package.ps1`                   | Add an MSIX package                     |
| `az-ps-update-avd-msix-package.ps1`                   | Update an MSIX package                  |
| `az-ps-remove-avd-msix-package.ps1`                   | Remove an MSIX package                  |
| `az-ps-update-avd-session-host.ps1`                   | Update a session host                   |
| `az-ps-remove-avd-session-host.ps1`                   | Remove a session host                   |
| `az-ps-remove-avd-user-session.ps1`                   | Disconnect / remove a user session      |
| `az-ps-send-avd-user-session-message.ps1`             | Send a message to a user session        |
| `az-ps-create-avd-registration-info.ps1`              | Generate host pool registration token   |
| `az-ps-remove-avd-registration-info.ps1`              | Revoke registration token               |
| `az-ps-remove-avd-scaling-plan.ps1`                   | Remove a scaling plan                   |
| `az-ps-remove-avd-scaling-plan-personal-schedule.ps1` | Remove personal scaling schedule        |
| `az-ps-remove-avd-scaling-plan-pooled-schedule.ps1`   | Remove pooled scaling schedule          |
| `az-ps-remove-avd-private-endpoint.ps1`               | Remove a private endpoint connection    |
| `az-ps-update-avd-desktop.ps1`                        | Update desktop properties               |
| `az-ps-assign-vm-to-avd-hostpool.ps1`                 | Assign a VM to a host pool              |
| `az-ps-create-resource-group.ps1`                     | Create the resource group               |
| `az-ps-remove-resource-group.ps1`                     | Remove the resource group               |
| `az-ps-create-key-vault.ps1`                          | Create a Key Vault for AVD secrets      |
| `az-ps-set-key-vault-secret.ps1`                      | Set a secret in Key Vault               |
| `az-ps-create-storage-account.ps1`                    | Create a storage account                |
| `az-ps-create-virtual-network.ps1`                    | Create the VNet for AVD                 |

### stack/\_todo/

Work-in-progress scripts for additional AVD automation including scaling plan creation and scheduled deployment scenarios.

## Related Documentation

- [Azure Virtual Desktop documentation](https://learn.microsoft.com/en-us/azure/virtual-desktop/)
- [Az.DesktopVirtualization module reference](https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/)
