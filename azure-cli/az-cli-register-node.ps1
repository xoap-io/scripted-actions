<#
.SYNOPSIS
    Register a new Azure VM in XOAP.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell. The script creates a new Azure Resource Group, a new Azure VM, and a new Azure Public IP Address.
    The script also retrieves the public IP address of the VM.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT


.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.Parameter AzResourceGroupName
    Defines the name of the Azure Resource Group.

.Parameter AzVmName
    Defines the name of the Azure VM.

.Parameter WorkspaceId
    Defines the ID of the XOAP Workspace to register this node.

.Parameter GroupName
    Defines the configuration management group name to assign the node to.

#>

param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$WorkspaceId,
	[Parameter(Mandatory)]
	[string]$GroupName
)

# Register VM in XOAP
az vm run-command invoke -g $AzResourceGroupName \
   --name $AzVmName \
   --command-id RunPowerShellScript \
   --scripts "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://api.dev.xoap.io/dsc/Policy/$WorkspaceId/Download/$GroupName'))"
