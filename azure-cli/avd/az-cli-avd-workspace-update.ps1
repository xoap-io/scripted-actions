<#
.SYNOPSIS
    Update an Azure Virtual Desktop workspace with the Azure CLI.

.DESCRIPTION
    This script updates an Azure Virtual Desktop workspace with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization workspace update --name $AzWorkspaceName --resource-group $AzResourceGroup

.PARAMETER Add
    Add an object to a list of objects by specifying a path and key value pairs.

.PARAMETER ApplicationGroupReferences
    The application group references.

.PARAMETER Description
    The description of the Azure Virtual Desktop workspace.

.PARAMETER ForceString
    Replace a string value with another string value.

.PARAMETER FriendlyName
    The friendly name of the Azure Virtual Desktop workspace.

.PARAMETER Ids
    One or more resource IDs (space-delimited).

.PARAMETER Name
    The name of the Azure Virtual Desktop workspace.

.PARAMETER Remove
    Remove a property or an element from a list.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Set
    Update an object by specifying a property path and value to set.

.PARAMETER Tags
    The tags for the Azure Virtual Desktop workspace.

.EXAMPLE
    .\az-cli-avd-workspace-update.ps1 -AzWorkspaceName "MyWorkspace" -AzResourceGroup "MyResourceGroup"

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
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Add,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupReferences,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ForceString,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Ids,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Remove,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Set,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

# Splatting parameters for better readability
$parameters = `
    '--add', $Add
    '--application-group-references', $ApplicationGroupReferences
    '--description', $Description
    '--force-string', $ForceString
    '--friendly-name', $FriendlyName
    '--ids', $Ids
    '--name', $Name
    '--remove', $Remove
    '--resource-group', $ResourceGroup
    '--set', $Set
    '--tags', $Tags

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Update the Azure Virtual Desktop workspace
    az desktopvirtualization workspace update @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop workspace updated successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to update the Azure Virtual Desktop workspace: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
