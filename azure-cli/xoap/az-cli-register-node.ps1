<#
.SYNOPSIS
    Register a new Azure VM in XOAP.

.DESCRIPTION
    This script registers a new Azure VM in XOAP. The script uses the Azure CLI to run a PowerShell script on the Azure VM.
    The PowerShell script downloads the DSC configuration from the XOAP platform and applies it to the Azure VM.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER VmName
    Defines the name of the Azure VM.

.PARAMETER WorkspaceId
    Defines the ID of the XOAP Workspace to register this node.

.PARAMETER GroupName
    Defines the XOAP config.XO group name to assign the node to.

.EXAMPLE
    .\az-cli-register-node.ps1 -AzResourceGroup "myResourceGroup" -AzVmName "myVmName" -WorkspaceId "myWorkspaceId" -GroupName "myGroupName"

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure CLI

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$VmName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$GroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$CommandId = "RunPowerShellScript",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Scripts = "Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://api.dev.xoap.io/dsc/Policy/$($parameters.workspace_id)/Download/$($parameters.group_name)'))"
)

# Splatting parameters for better readability
$parameters = `
    '--resource-group', $AzResourceGroup
    '--vmname', $AzVmName
    '--command-id', $CommandId
    '--scripts', $Scripts

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Register VM in XOAP
    az vm run-command invoke @parameters

    # Output the result
    Write-Output "Azure VM registered in XOAP successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to register Azure VM in XOAP: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
