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
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccount,

    [Parameter(Mandatory=$false)]
    [ValidateSet(
        'Cool',
        'Hot',
        'Premium',
        'TransactionOptimized'
    )]
    [string]$AccessTier,

    [Parameter(Mandatory=$false)]
    [ValidateSet(
        'NFS',
        'SMB'
    )]
    [string]$EnabledProtocols,

    [Parameter(Mandatory=$false)]
    [hashtable]$Metadata,

    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 5120)]
    [int]$Quota,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
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
    '--name', $Name ,`
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
    Write-Output "Azure Storage Account share created successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Storage Account share: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
