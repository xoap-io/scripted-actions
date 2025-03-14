<#
.SYNOPSIS
    Retrieve the registration token for an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script retrieves the registration token for an Azure Virtual Desktop Host Pool with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization hostpool retrieve-registration-token --name $AzHostPoolName --resource-group $AzResourceGroup

.PARAMETER IDs
    One or more resource IDs (space-delimited).

.PARAMETER Name
    The name of the Azure Virtual Desktop Host Pool.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.EXAMPLE
    .\az-cli-avd-hostpool-retrieve-registration-token.ps1 -AzHostPoolName "MyHostPool" -AzResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool?view=azure-cli-latest

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
    [string]$ResourceGroup
)

# Splatting parameters for better readability
$parameters = `
    '--ids', $Ids
    '--name', $HostPoolName
    '--resource-group', $ResourceGroup

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Retrieve the registration token for the Azure Virtual Desktop Host Pool
    az desktopvirtualization hostpool retrieve-registration-token @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Host Pool registration token retrieved successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to retrieve the Azure Virtual Desktop Host Pool registration token: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
