<#
.SYNOPSIS
    Install Nginx on an Azure Linux VM with Azure PowerShell.

.DESCRIPTION
    This script installs Nginx on an Azure Linux VM with Azure PowerShell. The script uses the Azure PowerShell to run a shell script on the specified Azure VM.
    The script uses the following Azure PowerShell command:
    Invoke-AzVMRunCommand -ResourceGroup $AzResourceGroup -Name $AzVmName -CommandId 'RunShellScript' -ScriptString 'sudo apt-get update && sudo apt-get install -y nginx'
    The script sets the ErrorActionPreference to Stop to handle errors properly.

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

.PARAMETER AzDebug
    Increase logging verbosity to show all debug logs.

.PARAMETER AzOnlyShowErrors
    Only show errors, suppressing warnings.

.PARAMETER AzOutput
    Output format.

.PARAMETER AzQuery
    JMESPath query string.

.PARAMETER AzVerbose
    Increase logging verbosity.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

.EXAMPLE
    .\az-ps-install-nginx-linux-vm.ps1 -AzResourceGroup "myResourceGroup" -AzVmName "myVm"

.NOTES
    Ensure that Azure PowerShell is installed and authenticated before running the script.
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure PowerShell

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = "myVm",

    [Parameter(Mandatory=$false)]
    [switch]$AzDebug,

    [Parameter(Mandatory=$false)]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory=$false)]
    [string]$AzOutput,

    [Parameter(Mandatory=$false)]
    [string]$AzQuery,

    [Parameter(Mandatory=$false)]
    [switch]$AzVerbose,


)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroup    = $AzResourceGroup
    Name                 = $AzVmName
    Debug                = $AzDebug
    OnlyShowErrors       = $AzOnlyShowErrors
    Output               = $AzOutput
    Query                = $AzQuery
    Verbose              = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Install Nginx on the VM
    Invoke-AzVMRunCommand @parameters -CommandId 'RunShellScript' -ScriptString 'sudo apt-get update && sudo apt-get install -y nginx'

    # Output the result
    Write-Output "Nginx installed successfully on Azure VM '$($AzVmName)'."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to install Nginx on Azure VM: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}