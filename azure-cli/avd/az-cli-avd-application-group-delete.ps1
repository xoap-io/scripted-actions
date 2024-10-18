<#
.SYNOPSIS
    Delete an Azure Virtual Desktop Application Group with the Azure CLI.

.DESCRIPTION
    This script deletes an Azure Virtual Desktop Application Group with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization applicationgroup delete --name $AzAppGroupName --resource-group $AzResourceGroup --subscription $AzSubscription --yes

.PARAMETER IDs
    The IDs of the Azure Virtual Desktop Application Group.

.PARAMETER Name
    Defines the name of the Azure Virtual Desktop Application Group.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER yes
    Do not prompt for confirmation.

.EXAMPLE
    .\az-cli-avd-applicationgroup-delete.ps1 -AzAppGroupName "MyAppGroup" -AzResourceGroup "MyResourceGroup" -AzSubscription "MySubscription" -AzYes

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$yes
)

# Splatting parameters for better readability
$parameters = `
    '--ids', $IDs
    '--name', $NName
    '--resource-group', $ResourceGroup
    '--yes', $yes

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Delete the Azure Virtual Desktop Application Group
    az desktopvirtualization applicationgroup delete @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Application Group deleted successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to delete the Azure Virtual Desktop Application Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
