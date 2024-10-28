<#
.SYNOPSIS
    Delete an Azure Storage Account with the Azure CLI.

.DESCRIPTION
    This script deletes a new Azure Storage Account with the Azure CLI.
    The script uses the following Azure CLI command:
    az storage account delete --name $StorageAccountName --resource-group $ResourceGroup

.PARAMETER Name
    Defines the name of the Azure Storage Account.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AccessTier
    Defines the access tier of the Azure Storage Account.

.EXAMPLE
    .\az-cli-create-storage-account.ps1 -AzStorageAccountName "MyStorageAccount" -AzResourceGroup "MyResourceGroup" -AzLocation "eastus" -AzStorageSku "Standard_LRS"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/storage/account

.LINK
    https://learn.microsoft.com/en-us/cli/azure/storage/account?view=azure-cli-latest

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
    [string]$Ids,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$Yes
)

# Splatting parameters for better readability
$parameters = `
    '--name', $Name
    '--resource-group', $ResourceGroup

if ($Yes) {
    $parameters += '--yes'
}

if ($Ids) {
    $parameters += '--ids', $Ids
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Delete a storage account
    az storage account delete @parameters

    # Output the result
    Write-Output "Azure Storage Account deleted successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to delete the Azure Storage Account: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
