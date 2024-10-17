<#
.SYNOPSIS
    Show details of an Azure Virtual Desktop workspace with the Azure CLI.

.DESCRIPTION
    This script shows details of an Azure Virtual Desktop workspace with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization workspace show --name $AzWorkspaceName --resource-group $AzResourceGroupName

.PARAMETER IDs
    One or more resource IDs (space-delimited).

.PARAMETER Name
    The name of the Azure Virtual Desktop Host Pool.

.PARAMETER ResourceGroupName
    The name of the Azure Resource Group.

.EXAMPLE
    .\az-cli-avd-workspace-show.ps1 -AzWorkspaceName "MyWorkspace" -AzResourceGroupName "MyResourceGroup"

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
    [string]$ResourceGroupName
)

# Splatting parameters for better readability
$parameters = @{
    '--ids' = $Ids
    '--name' = $HostPoolName
    '--resource-group' = $ResourceGroupName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Show details of the Azure Virtual Desktop workspace
    az desktopvirtualization workspace show @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop workspace details retrieved successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"
    Write-Error "Failed to retrieve the Azure Virtual Desktop workspace details: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
