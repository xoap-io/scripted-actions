<#
.SYNOPSIS
    Install Nginx on an Azure Linux VM with Azure PowerShell.

.DESCRIPTION
    This script installs Nginx on an Azure Linux VM with Azure PowerShell. The script uses the Azure PowerShell to run a shell script on the specified Azure VM.
    The script uses the following Azure PowerShell command:
    Invoke-AzVMRunCommand -ResourceGroupName $AzResourceGroupName -Name $AzVmName -CommandId 'RunShellScript' -ScriptString 'sudo apt-get update && sudo apt-get install -y nginx'
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
    Azure PowerShell

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzVmName = "myVm"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

Invoke-AzVMRunCommand `
   -ResourceGroupName $AzResourceGroupName `
   -Name $AzVmName `
   -CommandId 'RunShellScript' `
   -ScriptString 'sudo apt-get update && sudo apt-get install -y nginx'
