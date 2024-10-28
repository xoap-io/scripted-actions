<#
.SYNOPSIS
    This script deletes an Azure Resource Group with the Azure PowerShell.

.DESCRIPTION
    This script deletes an Azure Resource Group with the Azure PowerShell. The script requires the following parameter:
    - AzResourceGroup: Defines the name of the Azure Resource Group.

    The script will delete the Azure Resource Group with all its resources.

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.EXAMPLE
    .\Remove-AzResourceGroup.ps1 -AzResourceGroup "myResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.Resources

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.resources/remove-azresourcegroup?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup
)

# Splatting parameters for better readability
$parameters = @{
    Name = $AzResourceGroup
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Remove the Resource Group
    Remove-AzResourceGroup @parameters -Force

    # Output the result
    Write-Output "Azure Resource Group '$($ResourceGroup)' deleted successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"


    Write-Error "Failed to delete Azure Resource Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
