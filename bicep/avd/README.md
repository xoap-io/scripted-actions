# bicep/avd/

Bicep-based PowerShell scripts for deploying Azure Virtual Desktop
(AVD) infrastructure.

## Scripts

| Script                          | Description                                       |
| ------------------------------- | ------------------------------------------------- |
| `bicep-deploy-avd-hostpool.ps1` | Deploy an AVD host pool, workspace, and app group |

## bicep-deploy-avd-hostpool.ps1

Deploys a complete Azure Virtual Desktop control-plane environment:

- **Host pool** — Pooled or Personal, with configurable load balancing
- **Desktop application group** — associated with the host pool
- **Workspace** — linked to the desktop application group

Session hosts (VMs) are not deployed by this script. Add them
separately using the `bicep/vms/` or `azure-cli/vms/` scripts and
register them to the host pool using a registration token.

### Parameters

| Parameter           | Required | Default                          | Description                                   |
| ------------------- | -------- | -------------------------------- | --------------------------------------------- |
| `ResourceGroupName` | Yes      | —                                | Target Azure Resource Group                   |
| `Location`          | Yes      | —                                | Azure region (e.g. `eastus`)                  |
| `HostPoolName`      | Yes      | —                                | Name of the host pool                         |
| `WorkspaceName`     | Yes      | —                                | Name of the AVD workspace                     |
| `AppGroupName`      | No       | `<HostPoolName>-dag`             | Name of the desktop application group         |
| `HostPoolType`      | No       | `Pooled`                         | `Pooled` or `Personal`                        |
| `LoadBalancerType`  | No       | `BreadthFirst`                   | `BreadthFirst`, `DepthFirst`, or `Persistent` |
| `MaxSessionLimit`   | No       | `10`                             | Max sessions per session host (1–999999)      |
| `DeploymentName`    | No       | `<HostPoolName>-deployment-<ts>` | ARM deployment name                           |

### Usage

```powershell
# Deploy a pooled host pool with BreadthFirst load balancing
.\bicep-deploy-avd-hostpool.ps1 `
    -ResourceGroupName "rg-avd-prod" `
    -Location "eastus" `
    -HostPoolName "hp-prod-pooled" `
    -WorkspaceName "ws-prod" `
    -HostPoolType "Pooled" `
    -LoadBalancerType "BreadthFirst" `
    -MaxSessionLimit 20

# Deploy a personal host pool with Persistent assignment
.\bicep-deploy-avd-hostpool.ps1 `
    -ResourceGroupName "rg-avd-dev" `
    -Location "westeurope" `
    -HostPoolName "hp-dev-personal" `
    -WorkspaceName "ws-dev" `
    -AppGroupName "hp-dev-personal-dag" `
    -HostPoolType "Personal" `
    -LoadBalancerType "Persistent" `
    -MaxSessionLimit 1
```
