<#
.SYNOPSIS
    Deletes an Azure Storage share.

.DESCRIPTION
    This script deleted an Azure Storage share with the specified parameters using the Azure CLI.

.PARAMETER Ids
    One or more resource IDs (space-delimited).

.PARAMETER Include
    A comma-separated list of additional properties to include in the response.

.PARAMETER Name
    The name of the storage share.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER Snapshot
    The name of the snapshot.

.PARAMETER StorageAccount
    The name of the storage account.

.PARAMETER Yes
    Do not prompt for confirmation.

.EXAMPLE
    .\az-cli-delete-share.ps1 -Name "MyShare" -StorageAccount "MyStorageAccount" -ResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/storage/share-rm

.LINK
    https://learn.microsoft.com/en-us/cli/azure/storage/share-rm?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Ids,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Include,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Snapshot,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccount,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Subscription,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$Yes
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = `
    '--name', $Name
    '--storage-account', $StorageAccount
    '--resource-group', $ResourceGroup

if ($Ids) {
    $parameters += '--ids', $Ids
}

if ($Include) {
    $parameters += '--include', $Include
}

if ($Snapshot) {
    $parameters += '--snapshot', $Snapshot
}

if ($Yes) {
    $parameters += '--yes'
}

try {
    # Delete a share
    az storage share-rm delete @parameters

    # Output the result
    Write-Output "Azure Storage Account share deleted successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to delete the Azure Storage Account share: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
