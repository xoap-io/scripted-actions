<#
.SYNOPSIS
    Delete an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script deletes an Azure Virtual Desktop Host Pool with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization hostpool delete --name $AzHostPoolName --resource-group $AzResourceGroup

.EXAMPLE
    .\az-cli-avd-hostpool-delete.ps1 -AzHostPoolName "MyHostPool" -AzResourceGroup "MyResourceGroup"


.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Force,

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
    [switch]$Yes
)

# Splatting parameters for better readability
$parameters = `
    '--force', $Force
    '--ids', $Ids
    '--name', $HostPoolName
    '--resource-group', $AesourceGroup
    '--subscription', $Subscription
    '--yes', $Yes

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Delete the Azure Virtual Desktop Host Pool
    az desktopvirtualization hostpool delete @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Host Pool deleted successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to delete the Azure Virtual Desktop Host Pool: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
