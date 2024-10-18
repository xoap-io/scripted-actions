<#
.SYNOPSIS
    Show details of an Azure Virtual Desktop Application Group with the Azure CLI.

.DESCRIPTION
    This script shows details of an Azure Virtual Desktop Application Group with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization applicationgroup show --name $AzAppGroupName --resource-group $AzResourceGroup

.PARAMETER IDs
    One or more resource IDs (space-delimited).

.PARAMETER Name
    The name of the Azure Virtual Desktop Application Group.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.EXAMPLE
    .\az-cli-avd-applicationgroup-show.ps1 -AzAppGroupName "MyAppGroup" -AzResourceGroup "MyResourceGroup"

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
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$IDs,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup
)

# Splatting parameters for better readability
$parameters = `
    '--ids', $Ids
    '--name', $AppGroupName
    '--resource-group', $ResourceGroup

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Show details of the Azure Virtual Desktop Application Group
    az desktopvirtualization applicationgroup show @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Application Group details retrieved successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to retrieve the Azure Virtual Desktop Application Group details: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
