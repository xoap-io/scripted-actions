<#
.SYNOPSIS
    Create an Azure Virtual Desktop workspace with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Desktop workspace with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization workspace create --name $AzWorkspaceName --resource-group $AzResourceGroupName

.PARAMETER Name
    The name of the Azure Virtual Desktop workspace.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER ApplicationGroupReferences
    The application group references.

.PARAMETER Description
    The description of the Azure Virtual Desktop workspace.

.PARAMETER FriendlyName
    The friendly name of the Azure Virtual Desktop workspace.

.PARAMETER Location
    The location of the Azure Virtual Desktop workspace.

.PARAMETER Tags
    The tags for the Azure Virtual Desktop workspace.

.EXAMPLE
    .\az-cli-avd-workspace-create.ps1 -WorkspaceName "MyWorkspace" -ResourceGroupName "MyResourceGroup"

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
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupReferences,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

# Splatting parameters for better readability
$parameters = @{
    '--name' = $WorkspaceName
    '--resource-group' = $ResourceGroupName
}

if ($ApplicationGroupReferences) {
    $parameters += '--application-group-references', $AzApplicationGroupReferences
}

if ($Description) {
    $parameters += '--description', $AzDescription
}

if ($FriendlyName) {
    $parameters += '--friendly-name', $AzFriendlyName
}

if ($Location) {
    $parameters += '--location', $AzLocation
}

if ($Tags) {
    $parameters += '--tags', $AzTags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the Azure Virtual Desktop workspace
    az desktopvirtualization workspace create @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop workspace created successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"


    Write-Error "Failed to create the Azure Virtual Desktop workspace: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
