<#
.SYNOPSIS
    List Azure Virtual Desktop workspaces with the Azure CLI.

.DESCRIPTION
    This script lists Azure Virtual Desktop workspaces with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization workspace list --resource-group $AzResourceGroupName

.PARAMETER MaxItems
    Maximum number of items to return.

.PARAMETER NextToken
    Token to retrieve the next page of results.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.EXAMPLE
    .\az-cli-avd-workspace-list.ps1 -ResourceGroupName "MyResourceGroup"

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
    [string]$MaxItems,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NextToken,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup
)

# Splatting parameters for better readability
$parameters = @{
    '--max-items' = $MaxItems
    '--next-token' = $NextToken
    '--resource-group' = $ResourceGroup
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # List Azure Virtual Desktop workspaces
    az desktopvirtualization workspace list @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop workspaces listed successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"


    Write-Error "Failed to list the Azure Virtual Desktop workspaces: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
