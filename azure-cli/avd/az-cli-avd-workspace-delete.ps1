<#
.SYNOPSIS
    Delete an Azure Virtual Desktop workspace with the Azure CLI.

.DESCRIPTION
    This script deletes an Azure Virtual Desktop workspace with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization workspace delete --name $AzWorkspaceName --resource-group $AzResourceGroup

.PARAMETER IDs
    The IDs of the Azure Virtual Desktop workspace.

.PARAMETER Name
    Defines the name of the Azure Virtual Desktop workspace.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER yes
    Do not prompt for confirmation.

.EXAMPLE
    .\az-cli-avd-workspace-delete.ps1 -AzWorkspaceName "MyWorkspace" -AzResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/workspace

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/workspace?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$yes
)

# Splatting parameters for better readability
$parameters = `
    '--ids', $IDs
    '--name', $Name
    '--resource-group', $ResourceGroup
    '--yes', $yes

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Delete the Azure Virtual Desktop workspace
    az desktopvirtualization workspace delete @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop workspace deleted successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to delete the Azure Virtual Desktop workspace: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
