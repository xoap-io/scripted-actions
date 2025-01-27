<#
.SYNOPSIS
    Create a new Azure Storage Account with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Storage Account with the Azure CLI.
    The script uses the following Azure CLI command:
    az storage account create --name $AzStorageAccountName --resource-group $AzResourceGroup --location $AzLocation --sku $AzStorageSku

.PARAMETER Name
    Defines the name of the Azure Storage Account.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AccessTier
    Defines the access tier of the Azure Storage Account.

.PARAMETER AccountType
    Defines the account type of the Azure Storage Account.

.PARAMETER Action
    Defines the action of the Azure Storage Account.

.PARAMETER AllowAppend
    Defines the allow append value of the Azure Storage Account.

.PARAMETER AllowBlobPublicAccess
    Defines the allow blob public access value of the Azure Storage Account.

.PARAMETER AllowCrossTenantReplication
    Defines the allow cross-tenant replication value of the Azure Storage Account.

.PARAMETER AllowSharedKeyAccess
    Defines the allow shared key access value of the Azure Storage Account.

.PARAMETER AssignIdentity
    Defines the assign identity value of the Azure Storage Account.

.PARAMETER AzureStorageSid
    Defines the Azure Storage SID of the Azure Storage Account.

.PARAMETER Bypass
    Defines the bypass value of the Azure Storage Account.

.PARAMETER CustomDomain
    Defines the custom domain of the Azure Storage Account.

.PARAMETER DefaultAction
    Defines the default action of the Azure Storage Account.

.PARAMETER DefaultSharePermission
    Defines the default share permission of the Azure Storage Account.

.PARAMETER DnsEndpointType
    Defines the DNS endpoint type of the Azure Storage Account.

.PARAMETER DomainGuid
    Defines the domain GUID of the Azure Storage Account.

.PARAMETER DomainName
    Defines the domain name of the Azure Storage Account.

.PARAMETER DomainSid
    Defines the domain SID of the Azure Storage Account.

.PARAMETER EdgeZone
    Defines the edge zone of the Azure Storage Account.

.PARAMETER EnableAlw
    Defines the enable ALW value of the Azure Storage Account.

.PARAMETER EnableFilesAadds
    Defines the enable files AAD DS value of the Azure Storage Account.

.PARAMETER EnableFilesAadkerb
    Defines the enable files AAD Kerb value of the Azure Storage Account.

.PARAMETER EnableFilesAdds
    Defines the enable files ADS value of the Azure Storage Account.

.PARAMETER EnableHierarchicalNamespace
    Defines the enable hierarchical namespace value of the Azure Storage Account.

.PARAMETER EnableLargeFileShare
    Defines the enable large file share value of the Azure Storage Account.

.PARAMETER EnableLocalUser
    Defines the enable local user value of the Azure Storage Account.

.PARAMETER EnableNfsV3
    Defines the enable NFS v3 value of the Azure Storage Account.

.PARAMETER EnableSftp
    Defines the enable SFTP value of the Azure Storage Account.

.PARAMETER EncryptionKeyName
    Defines the encryption key name of the Azure Storage Account.

.PARAMETER EncryptionKeySource
    Defines the encryption key source of the Azure Storage Account.

.PARAMETER EncryptionKeyTypeForQueue
    Defines the encryption key type for the queue of the Azure Storage Account.

.PARAMETER EncryptionKeyTypeForTable
    Defines the encryption key type for the table of the Azure Storage Account.

.PARAMETER EncryptionKeyVault
    Defines the encryption key vault of the Azure Storage Account.

.PARAMETER EncryptionKeyVersion
    Defines the encryption key version of the Azure Storage Account.

.PARAMETER EncryptionServices
    Defines the encryption services of the Azure Storage Account.

.PARAMETER ForestName
    Defines the forest name of the Azure Storage Account.

.PARAMETER HttpsOnly
    Defines the HTTPS only value of the Azure Storage Account.

.PARAMETER IdentityType
    Defines the identity type of the Azure Storage Account.

.PARAMETER ImmutabilityPeriod
    Defines the immutability period of the Azure Storage Account.

.PARAMETER ImmutabilityState
    Defines the immutability state of the Azure Storage Account.

.PARAMETER KeyExpDays
    Defines the key expiration days of the Azure Storage Account.

.PARAMETER KeyVaultFederatedClientId
    Defines the key vault federated client ID of the Azure Storage Account.

.PARAMETER KeyVaultUserIdentityId
    Defines the key vault user identity ID of the Azure Storage Account.

.PARAMETER Kind
    Defines the kind of the Azure Storage Account.

.PARAMETER Location
    Defines the location of the Azure Storage Account.

.PARAMETER MinTlsVersion
    Defines the minimum TLS version of the Azure Storage Account.

.PARAMETER NetBiosDomainName
    Defines the NetBIOS domain name of the Azure Storage Account.

.PARAMETER PublicNetworkAccess
    Defines the public network access of the Azure Storage Account.

.PARAMETER PublishInternetEndpoints
    Defines the publish internet endpoints value of the Azure Storage Account.

.PARAMETER PublishMicrosoftEndpoints
    Defines the publish Microsoft endpoints value of the Azure Storage Account.

.PARAMETER RequireInfrastructureEncryption
    Defines the require infrastructure encryption value of the Azure Storage Account.

.PARAMETER RoutingChoice
    Defines the routing choice of the Azure Storage Account.

.PARAMETER SamAccountName
    Defines the SAM account name of the Azure Storage Account.

.PARAMETER SasExp
    Defines the SAS expiration value of the Azure Storage Account.

.PARAMETER Sku
    Defines the SKU of the Azure Storage Account.

.PARAMETER Subnet
    Defines the subnet of the Azure Storage Account.

.PARAMETER Tags
    Defines the tags for the Azure Storage Account.

.PARAMETER UserIdentityId
    Defines the user identity ID of the Azure Storage Account.

.PARAMETER VnetName
    Defines the VNet name of the Azure Storage Account.

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
    [string]$AccessTier,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AccountType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Action,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AllowAppend,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AllowBlobPublicAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AllowCrossTenantReplication,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AllowSharedKeyAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AssignIdentity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AzureStorageSid,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Bypass,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CustomDomain,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DefaultAction,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DefaultSharePermission,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DnsEndpointType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DomainGuid,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DomainName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DomainSid,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableAlw,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableFilesAadds,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableFilesAadkerb,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableFilesAdds,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableHierarchicalNamespace,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableLargeFileShare,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableLocalUser,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableNfsV3,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableSftp,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionKeyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionKeySource,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionKeyTypeForQueue,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionKeyTypeForTable,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionKeyVault,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionKeyVersion,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EncryptionServices,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ForestName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$HttpsOnly,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$IdentityType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ImmutabilityPeriod,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ImmutabilityState,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyExpDays,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultFederatedClientId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultUserIdentityId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Kind,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$MinTlsVersion,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NetBiosDomainName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublishInternetEndpoints,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublishMicrosoftEndpoints,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$RequireInfrastructureEncryption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$RoutingChoice,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SamAccountName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SasExp,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Sku,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Subnet,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$UserIdentityId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName
)

# Splatting parameters for better readability
$parameters = `
    '--name', $Name
    '--resource-group', $ResourceGroup

if ($AccessTier) {
    $parameters += '--access-tier', $AccessTier
}

if ($AccountType) {
    $parameters += '--account-type', $AccountType
}

if ($Action) {
    $parameters += '--action', $Action
}

if ($AllowAppend) {
    $parameters += '--allow-append', $AllowAppend
}

if ($AllowBlobPublicAccess) {
    $parameters += '--allow-blob-public-access', $AllowBlobPublicAccess
}

if ($AllowCrossTenantReplication) {
    $parameters += '--allow-cross-tenant-replication', $AllowCrossTenantReplication
}

if ($AllowSharedKeyAccess) {
    $parameters += '--allow-shared-key-access', $AllowSharedKeyAccess
}

if ($AssignIdentity) {
    $parameters += '--assign-identity', $AssignIdentity
}

if ($AzureStorageSid) {
    $parameters += '--azure-storage-sid', $AzureStorageSid
}

if ($Bypass) {
    $parameters += '--bypass', $Bypass
}

if ($CustomDomain) {
    $parameters += '--custom-domain', $CustomDomain
}

if ($DefaultAction) {
    $parameters += '--default-action', $DefaultAction
}

if ($DefaultSharePermission) {
    $parameters += '--default-share-permission', $DefaultSharePermission
}

if ($DnsEndpointType) {
    $parameters += '--dns-endpoint-type', $DnsEndpointType
}

if ($DomainGuid) {
    $parameters += '--domain-guid', $DomainGuid
}

if ($DomainName) {
    $parameters += '--domain-name', $DomainName
}

if ($DomainSid) {
    $parameters += '--domain-sid', $DomainSid
}

if ($EdgeZone) {
    $parameters += '--edge-zone', $EdgeZone
}

if ($EnableAlw) {
    $parameters += '--enable-alw', $EnableAlw
}

if ($EnableFilesAadds) {
    $parameters += '--enable-files-aadds', $EnableFilesAadds
}

if ($EnableFilesAadkerb) {
    $parameters += '--enable-files-aadkerb', $EnableFilesAadkerb
}

if ($EnableFilesAdds) {
    $parameters += '--enable-files-adds', $EnableFilesAdds
}

if ($EnableHierarchicalNamespace) {
    $parameters += '--enable-hierarchical-namespace', $EnableHierarchicalNamespace
}

if ($EnableLargeFileShare) {
    $parameters += '--enable-large-file-share', $EnableLargeFileShare
}

if ($EnableLocalUser) {
    $parameters += '--enable-local-user', $EnableLocalUser
}

if ($EnableNfsV3) {
    $parameters += '--enable-nfs-v3', $EnableNfsV3
}

if ($EnableSftp) {
    $parameters += '--enable-sftp', $EnableSftp
}

if ($EncryptionKeyName) {
    $parameters += '--encryption-key-name', $EncryptionKeyName
}

if ($EncryptionKeySource) {
    $parameters += '--encryption-key-source', $EncryptionKeySource
}

if ($EncryptionKeyTypeForQueue) {
    $parameters += '--encryption-key-type-for-queue', $EncryptionKeyTypeForQueue
}

if ($EncryptionKeyTypeForTable) {
    $parameters += '--encryption-key-type-for-table', $EncryptionKeyTypeForTable
}

if ($EncryptionKeyVault) {
    $parameters += '--encryption-key-vault', $EncryptionKeyVault
}

if ($EncryptionKeyVersion) {
    $parameters += '--encryption-key-version', $EncryptionKeyVersion
}

if ($EncryptionServices) {
    $parameters += '--encryption-services', $EncryptionServices
}

if ($ForestName) {
    $parameters += '--forest-name', $ForestName
}

if ($HttpsOnly) {
    $parameters += '--https-only', $HttpsOnly
}

if ($IdentityType) {
    $parameters += '--identity-type', $IdentityType
}

if ($ImmutabilityPeriod) {
    $parameters += '--immutability-period', $ImmutabilityPeriod
}

if ($ImmutabilityState) {
    $parameters += '--immutability-state', $ImmutabilityState
}

if ($KeyExpDays) {
    $parameters += '--key-exp-days', $KeyExpDays
}

if ($KeyVaultFederatedClientId) {
    $parameters += '--key-vault-federated-client-id', $KeyVaultFederatedClientId
}

if ($KeyVaultUserIdentityId) {
    $parameters += '--key-vault-user-identity-id', $KeyVaultUserIdentityId
}

if ($Kind) {
    $parameters += '--kind', $Kind
}

if ($Location) {
    $parameters += '--location', $Location
}

if ($MinTlsVersion) {
    $parameters += '--min-tls-version', $MinTlsVersion
}

if ($NetBiosDomainName) {
    $parameters += '--net-bios-domain-name', $NetBiosDomainName
}

if ($PublicNetworkAccess) {
    $parameters += '--public-network-access', $PublicNetworkAccess
}

if ($PublishInternetEndpoints) {
    $parameters += '--publish-internet-endpoints', $PublishInternetEndpoints
}

if ($PublishMicrosoftEndpoints) {
    $parameters += '--publish-microsoft-endpoints', $PublishMicrosoftEndpoints
}

if ($RequireInfrastructureEncryption) {
    $parameters += '--require-infrastructure-encryption', $RequireInfrastructureEncryption
}

if ($RoutingChoice) {
    $parameters += '--routing-choice', $RoutingChoice
}

if ($SamAccountName) {
    $parameters += '--sam-account-name', $SamAccountName
}

if ($SasExp) {
    $parameters += '--sas-exp', $SasExp
}

if ($Sku) {
    $parameters += '--sku', $Sku
}

if ($Subnet) {
    $parameters += '--subnet', $Subnet
}

if ($Tags) {
    $parameters += '--tags', $Tags
}

if ($UserIdentityId) {
    $parameters += '--user-identity-id', $UserIdentityId
}

if ($VnetName) {
    $parameters += '--vnet-name', $VnetName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create a storage account
    az storage account create @parameters

    # Output the result
    Write-Output "Azure Storage Account created successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Storage Account: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
