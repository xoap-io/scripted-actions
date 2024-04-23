<#
.SYNOPSIS
    Install a web server on an Azure Virtual Machine and open the specified ports.

.DESCRIPTION
    This script installs a web server on an Azure Virtual Machine and opens the specified ports.
    The script uses the Azure CLI to run a PowerShell script on the Azure Virtual Machine and open the specified ports.
    The script uses the following Azure CLI commands:
    az vm run-command invoke `
        --resource-group $AzResourceGroupName `
        --vm-name $VmName `
        --command-id RunPowerShellScript `
        --scripts $Script

    az vm open-port `
        --port $AZOpenPorts `
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

.PARAMETER VmName
    Defines the name of the Azure Virtual Machine.

.PARAMETER Script
    Defines the PowerShell command to run on the Azure Virtual Machine.

.PARAMETER AZOpenPorts
    Defines the ports to open on the Azure Virtual Machine.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzVmName,
    [Parameter(Mandatory)]
    [string]$Script = "Install-WindowsFeature -name Web-Server -IncludeManagementTools",
    [Parameter(Mandatory)]
    [string]$AzOpenPorts = '80'
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az vm run-command invoke `
    --resource-group $AzResourceGroupName `
    --vm-name $AzVmName `
    --command-id RunPowerShellScript `
    --scripts $Script

az vm open-port `
    --port $AzOpenPorts `
	--resource-group $AzResourceGroupName `
	--vm-name $AzVmName
