<#
.SYNOPSIS
    Delete an Azure Resource Group.

.DESCRIPTION
    This script deletes an Azure Resource Group.

    The script uses the Azure CLI to delete the specified Azure Resource Group.

    The script uses the following Azure CLI command:
    az group delete `
        --resource-group $AzResourceGroupName

    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.PARAMETER Name
    Defines the name of the Azure Resource Group.

.PARAMETER ForceDeletionTypes
    Defines the force deletion types of the Azure Resource Group.

.PARAMETER NoWait
    Defines the no-wait status of the Azure Resource Group.

.PARAMETER Yes
    Do not prompt for confirmation.

.LINK
    https://learn.microsoft.com/en-us/cli/azure/group

.LINK
    https://learn.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest

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

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Microsoft.Compute/virtualMachineScaleSets',
        'Microsoft.Compute/virtualMachines',
        'Microsoft.Databricks/workspaces'
    )]
    [string]$ForceDeletionTypes,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$NoWait,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$Yes
)

$parameters = `
    '--resource-group', $Name

if ($ForceDeletionTypes) {
    $parameters += '--force-deletion-types', $ForceDeletionTypes
}

if ($NoWait) {
    $parameters += '--no-wait'
}

if ($Yes) {
    $parameters += '--yes'
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Delete an Azure Resource Group
    az group delete @parameters

    # Output the result
    Write-Output "Azure Resource Group deleted successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"
    Write-Error "Failed to delete the Azure Resource Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
