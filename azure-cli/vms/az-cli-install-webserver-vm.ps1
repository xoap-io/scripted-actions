<#
.SYNOPSIS
    Install a web server on an Azure Virtual Machine and open the specified ports.

.DESCRIPTION
    This script installs a web server on an Azure Virtual Machine and opens the specified ports.
    The script uses the Azure CLI to run a PowerShell script on the Azure Virtual Machine and open the specified ports.
    The script uses the following Azure CLI commands:
    az vm run-command invoke `
        --resource-group $AzResourceGroup `
        --vm-name $VmName `
        --command-id RunPowerShellScript `
        --scripts $Script

    az vm open-port `
        --port $AZOpenPorts `
        --resource-group $AzResourceGroup `
        --vm-name $VmName

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzVmName
    Defines the name of the Azure Virtual Machine.

.PARAMETER Script
    Defines the PowerShell command to run on the Azure Virtual Machine.

.PARAMETER AzOpenPorts
    Defines the ports to open on the Azure Virtual Machine.

.EXAMPLE
    .\az-cli-install-webserver-vm.ps1 -AzResourceGroup "MyResourceGroup" -AzVmName "MyVmName" -Script "Install-WindowsFeature -name Web-Server -IncludeManagementTools" -AzOpenPorts "80"

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
    [string]$AzVmName = "myVmName",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Script = "Install-WindowsFeature -name Web-Server -IncludeManagementTools",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzOpenPorts = '80'
)

# Splatting parameters for better readability
$parameters = @{
    resource_group   = $AzResourceGroup
    vm_name          = $AzVmName
    command_id       = "RunPowerShellScript"
    scripts          = $Script
    port             = $AzOpenPorts
    debug            = $AzDebug
    only_show_errors = $AzOnlyShowErrors
    output           = $AzOutput
    query            = $AzQuery
    verbose          = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Install web server on the Azure VM
    az vm run-command invoke @parameters

    # Open the specified ports on the Azure VM
    az vm open-port @parameters

    # Output the result
    Write-Output "Web server installed and ports opened successfully on the Azure VM."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to install web server or open ports on the Azure VM: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}