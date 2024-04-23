<#
.SYNOPSIS
    This script installs the Web Server feature on a Windows VM in Azure.

.DESCRIPTION
    This script installs the Web Server feature on a Windows VM in Azure. The script uses the Azure PowerShell to run a PowerShell script on the specified Azure VM.
    The script uses the following Azure PowerShell command:
    Invoke-AzVMRunCommand -ResourceGroupName $AzResourceGroupName -VMName $AzVmName -CommandId 'RunPowerShellScript' -ScriptString 'Install-WindowsFeature -Name Web-Server -IncludeManagementTools'
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
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzVmName
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

Invoke-AzVMRunCommand `
	-ResourceGroupName $AzResourceGroupName `
	-VMName $AzVmName `
	-CommandId 'RunPowerShellScript' `
	-ScriptString 'Install-WindowsFeature -Name Web-Server -IncludeManagementTools'
