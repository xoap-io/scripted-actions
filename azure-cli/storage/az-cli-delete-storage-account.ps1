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
    .\az-cli-delete-storage-account.ps1 -Name "MyStorageAccount" -ResourceGroup "MyResourceGroup"

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
    https://learn.microsoft.com/en-us/cli/azure/storage/account

.COMPONENT
    Azure CLI Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Storage Account to delete")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "One or more resource IDs (space-delimited)")]
    [ValidateNotNullOrEmpty()]
    [string]$Ids,

    [Parameter(Mandatory = $false, HelpMessage = "Do not prompt for confirmation")]
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
    Write-Host "✅ Azure Storage Account deleted successfully." -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
