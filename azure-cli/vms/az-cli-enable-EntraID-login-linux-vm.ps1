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

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzExtensionName = "Microsoft.Azure.ActiveDirectory",

    [Parameter(Mandatory=$true)]
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
    Write-Output "EntraID login enabled for the Linux VM successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to enable EntraID login for the Linux VM: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}