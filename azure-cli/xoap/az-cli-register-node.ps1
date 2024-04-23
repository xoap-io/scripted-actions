<#
.SYNOPSIS
    Register a new Azure VM in XOAP.

.DESCRIPTION
    This script registers a new Azure VM in XOAP. The script uses the Azure CLI to run a PowerShell script on the Azure VM. 
    The PowerShell script downloads the DSC configuration from the XOAP platform and applies it to the Azure VM.

    The script uses the following Azure CLI command:
    az vm run-command invoke `
        --resource-group $AzResourceGroupName `
        --name $AzVmName `
        --command-id RunPowerShellScript `
        --scripts "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://api.dev.xoap.io/dsc/Policy/$WorkspaceId/Download/$GroupName'))"

    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    Azure CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

.PARAMETER WorkspaceId
    Defines the ID of the XOAP Workspace to register this node.

.PARAMETER GroupName
    Defines the XOAP config.XO group name to assign the node to.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzVmName = "myVmName",
    [Parameter(Mandatory)]
    [string]$XOAPWorkspaceId = "myWorkspaceId",
	[Parameter(Mandatory)]
	[string]$XOAPGroupName = "XOAP unassigned"
)

# Register VM in XOAP
az vm run-command invoke `
    --resource-group $AzResourceGroupName `
    --vm-name $AzVmName `
    --command-id RunPowerShellScript `
    --scripts "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://api.dev.xoap.io/dsc/Policy/$XOAPWorkspaceId/Download/$XOAPGroupName'))"
