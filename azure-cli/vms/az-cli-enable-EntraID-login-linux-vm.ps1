<#
.SYNOPSIS
    Enable EntraID login for a Linux VM in Azure.

.DESCRIPTION
    This script enables EntraID login for a Linux VM in Azure. The script uses the Azure CLI to set the AADSSHLoginForLinux extension for the specified Azure VM.
    The script uses the following Azure CLI command:
    az vm extension set `
        --publisher Microsoft.Azure.ActiveDirectory `
        --name AADSSHLoginForLinux `
        --resource-group $AzResourceGroup `
        --vm-name $AzVmName

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzExtensionName
    Defines the name of the Azure Extension.

.PARAMETER AzVmName
    Defines the name of the Azure Virtual Machine.

.EXAMPLE
    .\az-cli-enable-EntraID-login-linux-vm.ps1 -AzResourceGroup "MyResourceGroup" -AzExtensionName "Microsoft.Azure.ActiveDirectory" -AzVmName "MyVmName"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure VM extension publisher")]
    [ValidateNotNullOrEmpty()]
    [string]$AzExtensionName = "Microsoft.Azure.ActiveDirectory",

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Machine")]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = "myVmName"
)

# Splatting parameters for better readability
$parameters = @{
    publisher        = $AzExtensionName
    name             = $AzExtensionName
    resource_group   = $AzResourceGroup
    vm_name          = $AzVmName
    debug            = $AzDebug
    only_show_errors = $AzOnlyShowErrors
    output           = $AzOutput
    query            = $AzQuery
    verbose          = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Enable EntraID login for the Linux VM
    az vm extension set @parameters

    # Output the result
    Write-Host "✅ EntraID login enabled for the Linux VM successfully." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
