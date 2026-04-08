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

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/storage/share-rm

.COMPONENT
    Azure CLI Storage
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, HelpMessage = "One or more resource IDs (space-delimited)")]
    [ValidateNotNullOrEmpty()]
    [string]$Ids,

    [Parameter(Mandatory = $false, HelpMessage = "A comma-separated list of additional properties to include in the response")]
    [ValidateNotNullOrEmpty()]
    [string]$Include,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the storage share")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the resource group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the snapshot")]
    [ValidateNotNullOrEmpty()]
    [string]$Snapshot,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the storage account")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccount,

    [Parameter(Mandatory = $false, HelpMessage = "The subscription ID")]
    [ValidateNotNullOrEmpty()]
    [string]$Subscription,

    [Parameter(Mandatory = $false, HelpMessage = "Do not prompt for confirmation")]
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
    Write-Host "✅ Azure Storage Account share deleted successfully." -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
