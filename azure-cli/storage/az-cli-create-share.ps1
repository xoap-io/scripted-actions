<#
.SYNOPSIS
    Creates an Azure Storage share.

.DESCRIPTION
    This script creates an Azure Storage share with the specified parameters using the Azure CLI.

.PARAMETER Name
    The name of the storage share.

.PARAMETER StorageAccount
    The name of the storage account.

.PARAMETER AccessTier
    The access tier of the storage share. Valid values are Cool, Hot, Premium, TransactionOptimized.

.PARAMETER EnabledProtocols
    The enabled protocols for the storage share. Valid values are NFS, SMB.

.PARAMETER Metadata
    A hashtable of metadata to apply to the storage share.

.PARAMETER Quota
    The quota for the storage share in GB.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER RootSquash
    The root squash setting for the storage share. Valid values are AllSquash, NoRootSquash, RootSquash.

.EXAMPLE
    .\az-cli-create-share.ps1 -Name "MyShare" -StorageAccount "MyStorageAccount" -AccessTier "Hot" -EnabledProtocols "SMB" -Quota 100 -ResourceGroup "MyResourceGroup"

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
    [Parameter(Mandatory = $true, HelpMessage = "The name of the storage share")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the storage account")]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccount,

    [Parameter(Mandatory = $false, HelpMessage = "The access tier of the storage share")]
    [ValidateSet(
        'Cool',
        'Hot',
        'Premium',
        'TransactionOptimized'
    )]
    [string]$AccessTier,

    [Parameter(Mandatory = $false, HelpMessage = "The enabled protocols for the storage share")]
    [ValidateSet(
        'NFS',
        'SMB'
    )]
    [string]$EnabledProtocols,

    [Parameter(Mandatory = $false, HelpMessage = "A hashtable of metadata to apply to the storage share")]
    [hashtable]$Metadata,

    [Parameter(Mandatory = $false, HelpMessage = "The quota for the storage share in GB")]
    [ValidateRange(1, 5120)]
    [int]$Quota,

    [Parameter(Mandatory = $false, HelpMessage = "The name of the resource group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "The root squash setting for the storage share")]
    [ValidateSet(
        'AllSquash',
        'NoRootSquash',
        'RootSquash'
    )]
    [string]$RootSquash
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = `
    '--name', $Name
    '--storage-account', $StorageAccount

if ($AccessTier) {
    $parameters += '--access-tier', $AccessTier
}

if ($EnabledProtocols) {
    $parameters += '--enabled-protocols', $EnabledProtocols
}

if ($Metadata) {
    $parameters += '--metadata', $Metadata
}

if ($Quota) {
    $parameters += '--quota', $Quota
}

if ($ResourceGroup) {
    $parameters += '--resource-group', $ResourceGroup
}

if ($RootSquash) {
    $parameters += '--root-squash', $RootSquash
}

try {
    # Create a new share
    az storage share-rm create @parameters

    # Output the result
    Write-Host "✅ Azure Storage Account share created successfully." -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
