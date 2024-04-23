<#
.SYNOPSIS
    Enable EntraID login for a Linux VM in Azure.

.DESCRIPTION
    This script enables EntraID login for a Linux VM in Azure. The script uses the Azure CLI to set the AADSSHLoginForLinux extension for the specified Azure VM.
    The script uses the following Azure CLI command:
    az vm extension set `
        --publisher Microsoft.Azure.ActiveDirectory `
        --name AADSSHLoginForLinux `
        --resource-group $AzResourceGroupName `
        --vm-name $VmName

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

.PARAMETER AzExtensionName
    Defines the name of the Azure Extension.

.PARAMETER AzVmName
    Defines the name of the Azure Virtual Machine.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzExtensionName = "Microsoft.Azure.ActiveDirectory",
    [Parameter(Mandatory)]
    [string]$AzVmName = "myVmName"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

az vm extension set `
    --publisher $AzExtensionName `
    --name $AzExtensionName `
    --resource-group $AzResourceGroupName `
    --vm-name $AzVmName

# Output IP address for SSH access
export IP_ADDRESS = $(az vm show --show-details --resource-group $AzResourceGroupName --name $AzVmName --query publicIps --output tsv)
