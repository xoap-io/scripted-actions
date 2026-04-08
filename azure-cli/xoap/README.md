# XOAP Operations Scripts

PowerShell scripts for XOAP platform-specific Azure operations using Azure CLI.

## Prerequisites

- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- Active Azure subscription and logged-in CLI session (`az login`)
- XOAP Workspace ID and group name for node registration

## Available Scripts

| Script | Description |
| --- | --- |
| `az-cli-register-node.ps1` | Register an Azure VM as a node in an XOAP Workspace by running the DSC bootstrap script via `az vm run-command invoke` |

## Usage Examples

### Register a Node in XOAP

```powershell
.\az-cli-register-node.ps1 `
    -ResourceGroup "rg-vms" `
    -VmName "vm-web-prod-01" `
    -WorkspaceId "my-xoap-workspace-id" `
    -GroupName "production-web"
```

## Notes

- The script uses `az vm run-command invoke` to execute a PowerShell
  one-liner on the target VM that downloads and applies the DSC
  configuration from the XOAP API (`https://api.xoap.io`).
- The VM must be running and reachable by the Azure Run Command service.
- The `-CommandId` parameter defaults to `RunPowerShellScript` and does
  not need to be changed under normal circumstances.
