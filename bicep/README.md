# bicep/

PowerShell scripts that deploy Azure resources declaratively using
**Azure Bicep** via the Azure CLI. Each script writes an inline Bicep
template to a temporary file, calls
`az deployment group create --template-file`, and cleans up the temp
file automatically — no external `.bicep` files are required.

## Prerequisites

- **Azure CLI** ≥ 2.50 —
  [install guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- **Bicep CLI** — install once with `az bicep install`
- An active Azure subscription with sufficient permissions to create
  resources in the target resource group

## Subdirectories

| Directory     | Description                                      |
| ------------- | ------------------------------------------------ |
| `vms/`        | Windows VM deployments (VM, NIC, VNet, NSG, PIP) |
| `networking/` | Virtual Network deployments with subnets         |
| `avd/`        | Azure Virtual Desktop host pool + workspace      |

## Usage Pattern

All scripts follow the same pattern:

```powershell
# 1. Ensure az bicep is installed
az bicep install

# 2. Log in to Azure (if not already authenticated)
az login
az account set --subscription "<subscription-id>"

# 3. Run the deployment script
.\bicep\vms\bicep-deploy-windows-vm.ps1 `
    -ResourceGroupName "rg-prod" `
    -VmName "vm-web-01" `
    -Location "eastus" `
    -AdminUsername "azureadmin" `
    -AdminPassword (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) `
    -AddPublicIp
```

## Temp File Handling

Each script:

1. Generates an inline Bicep template string at runtime.
2. Writes it to a uniquely named `.bicep` file in the system temp
   directory.
3. Passes the file path to `az deployment group create`.
4. Removes the temp file in the `finally` block — even if the
   deployment fails.

## Script Naming Convention

Scripts follow the repository convention:

```
bicep-{action}-{resource}.ps1
```
