<#
.SYNOPSIS
    List Azure Virtual Desktop Application Groups with the Azure CLI.

.DESCRIPTION
    This script lists Azure Virtual Desktop Application Groups with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization applicationgroup list --resource-group $AzResourceGroup

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Filter
    OData filter.

.PARAMETER MaxItems
    Maximum number of items to return.

.PARAMETER NextToken
    Token to retrieve the next page of results.

.EXAMPLE
    .\az-cli-avd-applicationgroup-list.ps1 -AzResourceGroup "MyResourceGroup"

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
    [string]$Filter,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$MaxItems,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$NextToken,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup
)

# Splatting parameters for better readability
$parameters = `
    '--filter', $Filter
    '--max-items', $MaxItems
    '--next-token', $NextToken
    '--resource-group', $ResourceGroup

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # List the Azure Virtual Desktop Application Groups
    az desktopvirtualization applicationgroup list @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Application Groups listed successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to list the Azure Virtual Desktop Application Groups: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
