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
    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Virtual Machine")]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = "myVmName",

    [Parameter(Mandatory = $false, HelpMessage = "The PowerShell script to run on the Azure VM")]
    [ValidateNotNullOrEmpty()]
    [string]$Script = "Install-WindowsFeature -name Web-Server -IncludeManagementTools",

    [Parameter(Mandatory = $false, HelpMessage = "The ports to open on the Azure VM")]
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
    Write-Host "✅ Web server installed and ports opened successfully on the Azure VM." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
