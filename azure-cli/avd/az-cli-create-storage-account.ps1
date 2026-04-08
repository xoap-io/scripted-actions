<#
.SYNOPSIS
    Create a new Azure Storage Account with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Storage Account with comprehensive configuration options using the Azure CLI.
    The script uses the Azure CLI command: az storage account create

    The script supports all major storage account configuration options including:
    - Access tiers and account types
    - Security and encryption settings
    - Network access controls
    - Identity and authentication options
    - File service configurations

.PARAMETER Name
    The name of the Azure Storage Account. Must be globally unique and between 3-24 characters.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the storage account will be created.

.PARAMETER Location
    The Azure region where the storage account will be created (e.g., 'eastus', 'westus2').

.PARAMETER Sku
    The SKU (performance tier and replication type) for the storage account.
    Valid values: 'Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS', 'Premium_ZRS', 'Standard_GZRS', 'Standard_RAGZRS'

.PARAMETER AccessTier
    The access tier for blob storage accounts.
    Valid values: 'Hot', 'Cool'

.PARAMETER Kind
    The kind of storage account.
    Valid values: 'Storage', 'StorageV2', 'BlobStorage', 'FileStorage', 'BlockBlobStorage'

.PARAMETER AllowBlobPublicAccess
    Allow or disallow public access to blobs in the storage account.

.PARAMETER AllowCrossTenantReplication
    Allow or disallow cross-tenant replication for the storage account.

.PARAMETER AllowSharedKeyAccess
    Allow or disallow shared key access to the storage account.

.PARAMETER HttpsOnly
    Only allow HTTPS traffic to the storage account.

.PARAMETER MinTlsVersion
    The minimum TLS version required for requests to the storage account.
    Valid values: 'TLS1_0', 'TLS1_1', 'TLS1_2'

.PARAMETER PublicNetworkAccess
    Control public network access to the storage account.
    Valid values: 'Enabled', 'Disabled'

.PARAMETER EnableHierarchicalNamespace
    Enable hierarchical namespace for Azure Data Lake Storage Gen2.

.PARAMETER EnableLargeFileShare
    Enable large file shares for the storage account.

.PARAMETER EnableNfsV3
    Enable NFS v3 protocol support.

.PARAMETER EnableSftp
    Enable SFTP support for the storage account.

.PARAMETER IdentityType
    The type of managed identity to assign to the storage account.
    Valid values: 'SystemAssigned', 'UserAssigned', 'SystemAssigned,UserAssigned', 'None'

.PARAMETER EncryptionKeySource
    The source of the encryption key.
    Valid values: 'Microsoft.Storage', 'Microsoft.Keyvault'

.PARAMETER Tags
    Tags to apply to the storage account in the format 'key1=value1 key2=value2'.

.PARAMETER CustomDomain
    Custom domain name for the storage account.

.PARAMETER DefaultAction
    Default action for network rules.
    Valid values: 'Allow', 'Deny'

.PARAMETER Bypass
    Network rule bypass options.
    Valid values: 'AzureServices', 'Logging', 'Metrics', 'None'

.PARAMETER Subnet
    Subnet resource ID for network rules.

.PARAMETER VnetName
    Virtual network name for network rules.

.PARAMETER AssignIdentity
    Assign a managed identity to the storage account.

.PARAMETER UserIdentityId
    Resource ID of the user-assigned managed identity.

.PARAMETER EncryptionKeyVault
    Key vault URI for customer-managed encryption keys.

.PARAMETER EncryptionKeyName
    Name of the encryption key in the key vault.

.PARAMETER EncryptionKeyVersion
    Version of the encryption key.

.PARAMETER RequireInfrastructureEncryption
    Require infrastructure encryption for the storage account.

.PARAMETER RoutingChoice
    Routing preference for the storage account.
    Valid values: 'MicrosoftRouting', 'InternetRouting'

.PARAMETER PublishInternetEndpoints
    Publish internet endpoints for the storage account.

.PARAMETER PublishMicrosoftEndpoints
    Publish Microsoft endpoints for the storage account.

.PARAMETER EdgeZone
    Edge zone name for the storage account.

.PARAMETER AccountType
    Account type (legacy parameter, use Kind instead).

.PARAMETER Action
    Action for network rules (legacy parameter, use DefaultAction instead).

.PARAMETER AllowAppend
    Allow append operations (blob-specific setting).

.PARAMETER AzureStorageSid
    Azure Storage SID for file service integration.

.PARAMETER DefaultSharePermission
    Default share permission for file shares.

.PARAMETER DnsEndpointType
    DNS endpoint type for the storage account.

.PARAMETER DomainGuid
    Domain GUID for Active Directory integration.

.PARAMETER DomainName
    Domain name for Active Directory integration.

.PARAMETER DomainSid
    Domain SID for Active Directory integration.

.PARAMETER EnableAlw
    Enable advanced threat protection.

.PARAMETER EnableFilesAadds
    Enable Azure Active Directory Domain Services authentication for file shares.

.PARAMETER EnableFilesAadkerb
    Enable Azure Active Directory Kerberos authentication for file shares.

.PARAMETER EnableFilesAdds
    Enable Active Directory Domain Services authentication for file shares.

.PARAMETER EnableLocalUser
    Enable local users for SFTP.

.PARAMETER EncryptionKeyTypeForQueue
    Encryption key type for queue service.

.PARAMETER EncryptionKeyTypeForTable
    Encryption key type for table service.

.PARAMETER EncryptionServices
    Storage services to encrypt.

.PARAMETER ForestName
    Forest name for Active Directory integration.

.PARAMETER ImmutabilityPeriod
    Immutability period for legal hold policies.

.PARAMETER ImmutabilityState
    Immutability state for legal hold policies.

.PARAMETER KeyExpDays
    Key expiration days for shared access signatures.

.PARAMETER KeyVaultFederatedClientId
    Key vault federated client ID.

.PARAMETER KeyVaultUserIdentityId
    Key vault user identity ID.

.PARAMETER NetBiosDomainName
    NetBIOS domain name for Active Directory integration.

.PARAMETER SamAccountName
    SAM account name for Active Directory integration.

.PARAMETER SasExp
    SAS expiration policy.

.EXAMPLE
    .\az-cli-create-storage-account.ps1 -Name "mystorageaccount" -ResourceGroup "myresourcegroup" -Location "eastus" -Sku "Standard_LRS"

    Creates a basic storage account with locally redundant storage.

.EXAMPLE
    .\az-cli-create-storage-account.ps1 -Name "mystorageaccount" -ResourceGroup "myresourcegroup" -Location "eastus" -Sku "Standard_LRS" -Kind "StorageV2" -AccessTier "Hot" -HttpsOnly -Tags "environment=production team=devops"

    Creates a general-purpose v2 storage account with hot access tier and HTTPS-only access.

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

.LINK
    https://learn.microsoft.com/en-us/azure/storage/common/storage-account-overview

.COMPONENT
    Azure CLI Virtual Desktop
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Storage Account")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(3, 24)]
    [ValidatePattern('^[a-z0-9]+$', ErrorMessage = "Storage account name must be 3-24 characters, lowercase letters and numbers only")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "The Azure region where the storage account will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(HelpMessage = "The SKU (performance tier and replication type) for the storage account")]
    [ValidateSet('Standard_LRS', 'Standard_GRS', 'Standard_RAGRS', 'Standard_ZRS', 'Premium_LRS', 'Premium_ZRS', 'Standard_GZRS', 'Standard_RAGZRS')]
    [string]$Sku,

    [Parameter(HelpMessage = "The access tier for blob storage accounts")]
    [ValidateSet('Hot', 'Cool')]
    [string]$AccessTier,

    [Parameter(HelpMessage = "The kind of storage account")]
    [ValidateSet('Storage', 'StorageV2', 'BlobStorage', 'FileStorage', 'BlockBlobStorage')]
    [string]$Kind,

    [Parameter(HelpMessage = "Allow or disallow public access to blobs")]
    [switch]$AllowBlobPublicAccess,

    [Parameter(HelpMessage = "Allow or disallow cross-tenant replication")]
    [switch]$AllowCrossTenantReplication,

    [Parameter(HelpMessage = "Allow or disallow shared key access")]
    [switch]$AllowSharedKeyAccess,

    [Parameter(HelpMessage = "Only allow HTTPS traffic")]
    [switch]$HttpsOnly,

    [Parameter(HelpMessage = "The minimum TLS version required")]
    [ValidateSet('TLS1_0', 'TLS1_1', 'TLS1_2')]
    [string]$MinTlsVersion,

    [Parameter(HelpMessage = "Control public network access")]
    [ValidateSet('Enabled', 'Disabled')]
    [string]$PublicNetworkAccess,

    [Parameter(HelpMessage = "Enable hierarchical namespace for Data Lake Storage Gen2")]
    [switch]$EnableHierarchicalNamespace,

    [Parameter(HelpMessage = "Enable large file shares")]
    [switch]$EnableLargeFileShare,

    [Parameter(HelpMessage = "Enable NFS v3 protocol support")]
    [switch]$EnableNfsV3,

    [Parameter(HelpMessage = "Enable SFTP support")]
    [switch]$EnableSftp,

    [Parameter(HelpMessage = "The type of managed identity to assign")]
    [ValidateSet('SystemAssigned', 'UserAssigned', 'SystemAssigned,UserAssigned', 'None')]
    [string]$IdentityType,

    [Parameter(HelpMessage = "The source of the encryption key")]
    [ValidateSet('Microsoft.Storage', 'Microsoft.Keyvault')]
    [string]$EncryptionKeySource,

    [Parameter(HelpMessage = "Tags to apply in the format 'key1=value1 key2=value2'")]
    [string]$Tags,

    [Parameter(HelpMessage = "Custom domain name")]
    [string]$CustomDomain,

    [Parameter(HelpMessage = "Default action for network rules")]
    [ValidateSet('Allow', 'Deny')]
    [string]$DefaultAction,

    [Parameter(HelpMessage = "Network rule bypass options")]
    [ValidateSet('AzureServices', 'Logging', 'Metrics', 'None')]
    [string]$Bypass,

    [Parameter(HelpMessage = "Subnet resource ID for network rules")]
    [string]$Subnet,

    [Parameter(HelpMessage = "Virtual network name for network rules")]
    [string]$VnetName,

    [Parameter(HelpMessage = "Assign a managed identity")]
    [switch]$AssignIdentity,

    [Parameter(HelpMessage = "Resource ID of user-assigned managed identity")]
    [string]$UserIdentityId,

    [Parameter(HelpMessage = "Key vault URI for customer-managed encryption")]
    [string]$EncryptionKeyVault,

    [Parameter(HelpMessage = "Name of the encryption key")]
    [string]$EncryptionKeyName,

    [Parameter(HelpMessage = "Version of the encryption key")]
    [string]$EncryptionKeyVersion,

    [Parameter(HelpMessage = "Require infrastructure encryption")]
    [switch]$RequireInfrastructureEncryption,

    [Parameter(HelpMessage = "Routing preference")]
    [ValidateSet('MicrosoftRouting', 'InternetRouting')]
    [string]$RoutingChoice,

    [Parameter(HelpMessage = "Publish internet endpoints")]
    [switch]$PublishInternetEndpoints,

    [Parameter(HelpMessage = "Publish Microsoft endpoints")]
    [switch]$PublishMicrosoftEndpoints,

    [Parameter(HelpMessage = "Edge zone name")]
    [string]$EdgeZone,

    # Legacy/Advanced Parameters
    [Parameter(HelpMessage = "Account type (legacy parameter)")]
    [string]$AccountType,

    [Parameter(HelpMessage = "Action for network rules (legacy parameter)")]
    [string]$Action,

    [Parameter(HelpMessage = "Allow append operations")]
    [switch]$AllowAppend,

    [Parameter(HelpMessage = "Azure Storage SID for file service integration")]
    [string]$AzureStorageSid,

    [Parameter(HelpMessage = "Default share permission for file shares")]
    [string]$DefaultSharePermission,

    [Parameter(HelpMessage = "DNS endpoint type")]
    [string]$DnsEndpointType,

    [Parameter(HelpMessage = "Domain GUID for AD integration")]
    [string]$DomainGuid,

    [Parameter(HelpMessage = "Domain name for AD integration")]
    [string]$DomainName,

    [Parameter(HelpMessage = "Domain SID for AD integration")]
    [string]$DomainSid,

    [Parameter(HelpMessage = "Enable advanced threat protection")]
    [switch]$EnableAlw,

    [Parameter(HelpMessage = "Enable Azure AD Domain Services authentication")]
    [switch]$EnableFilesAadds,

    [Parameter(HelpMessage = "Enable Azure AD Kerberos authentication")]
    [switch]$EnableFilesAadkerb,

    [Parameter(HelpMessage = "Enable AD Domain Services authentication")]
    [switch]$EnableFilesAdds,

    [Parameter(HelpMessage = "Enable local users for SFTP")]
    [switch]$EnableLocalUser,

    [Parameter(HelpMessage = "Encryption key type for queue service")]
    [string]$EncryptionKeyTypeForQueue,

    [Parameter(HelpMessage = "Encryption key type for table service")]
    [string]$EncryptionKeyTypeForTable,

    [Parameter(HelpMessage = "Storage services to encrypt")]
    [string]$EncryptionServices,

    [Parameter(HelpMessage = "Forest name for AD integration")]
    [string]$ForestName,

    [Parameter(HelpMessage = "Immutability period for legal hold")]
    [string]$ImmutabilityPeriod,

    [Parameter(HelpMessage = "Immutability state for legal hold")]
    [string]$ImmutabilityState,

    [Parameter(HelpMessage = "Key expiration days for SAS")]
    [string]$KeyExpDays,

    [Parameter(HelpMessage = "Key vault federated client ID")]
    [string]$KeyVaultFederatedClientId,

    [Parameter(HelpMessage = "Key vault user identity ID")]
    [string]$KeyVaultUserIdentityId,

    [Parameter(HelpMessage = "NetBIOS domain name for AD integration")]
    [string]$NetBiosDomainName,

    [Parameter(HelpMessage = "SAM account name for AD integration")]
    [string]$SamAccountName,

    [Parameter(HelpMessage = "SAS expiration policy")]
    [string]$SasExp
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    # Check if Azure CLI is available
    if (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not found in PATH. Please install Azure CLI first."
    }

    # Check if user is logged in to Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }

    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan

    # Build Azure CLI command parameters
    $azParams = @(
        'storage', 'account', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup
    )

    # Add optional parameters
    if ($Location) { $azParams += '--location', $Location }
    if ($Sku) { $azParams += '--sku', $Sku }
    if ($AccessTier) { $azParams += '--access-tier', $AccessTier }
    if ($Kind) { $azParams += '--kind', $Kind }
    if ($AllowBlobPublicAccess) { $azParams += '--allow-blob-public-access', 'true' }
    if ($AllowCrossTenantReplication) { $azParams += '--allow-cross-tenant-replication', 'true' }
    if ($AllowSharedKeyAccess) { $azParams += '--allow-shared-key-access', 'true' }
    if ($HttpsOnly) { $azParams += '--https-only', 'true' }
    if ($MinTlsVersion) { $azParams += '--min-tls-version', $MinTlsVersion }
    if ($PublicNetworkAccess) { $azParams += '--public-network-access', $PublicNetworkAccess }
    if ($EnableHierarchicalNamespace) { $azParams += '--enable-hierarchical-namespace', 'true' }
    if ($EnableLargeFileShare) { $azParams += '--enable-large-file-share', 'true' }
    if ($EnableNfsV3) { $azParams += '--enable-nfs-v3', 'true' }
    if ($EnableSftp) { $azParams += '--enable-sftp', 'true' }
    if ($IdentityType) { $azParams += '--identity-type', $IdentityType }
    if ($EncryptionKeySource) { $azParams += '--encryption-key-source', $EncryptionKeySource }
    if ($Tags) { $azParams += '--tags', $Tags }
    if ($CustomDomain) { $azParams += '--custom-domain', $CustomDomain }
    if ($DefaultAction) { $azParams += '--default-action', $DefaultAction }
    if ($Bypass) { $azParams += '--bypass', $Bypass }
    if ($Subnet) { $azParams += '--subnet', $Subnet }
    if ($VnetName) { $azParams += '--vnet-name', $VnetName }
    if ($AssignIdentity) { $azParams += '--assign-identity' }
    if ($UserIdentityId) { $azParams += '--user-identity-id', $UserIdentityId }
    if ($EncryptionKeyVault) { $azParams += '--encryption-key-vault', $EncryptionKeyVault }
    if ($EncryptionKeyName) { $azParams += '--encryption-key-name', $EncryptionKeyName }
    if ($EncryptionKeyVersion) { $azParams += '--encryption-key-version', $EncryptionKeyVersion }
    if ($RequireInfrastructureEncryption) { $azParams += '--require-infrastructure-encryption', 'true' }
    if ($RoutingChoice) { $azParams += '--routing-choice', $RoutingChoice }
    if ($PublishInternetEndpoints) { $azParams += '--publish-internet-endpoints', 'true' }
    if ($PublishMicrosoftEndpoints) { $azParams += '--publish-microsoft-endpoints', 'true' }
    if ($EdgeZone) { $azParams += '--edge-zone', $EdgeZone }

    # Legacy/Advanced parameters
    if ($AccountType) { $azParams += '--account-type', $AccountType }
    if ($Action) { $azParams += '--action', $Action }
    if ($AllowAppend) { $azParams += '--allow-append', 'true' }
    if ($AzureStorageSid) { $azParams += '--azure-storage-sid', $AzureStorageSid }
    if ($DefaultSharePermission) { $azParams += '--default-share-permission', $DefaultSharePermission }
    if ($DnsEndpointType) { $azParams += '--dns-endpoint-type', $DnsEndpointType }
    if ($DomainGuid) { $azParams += '--domain-guid', $DomainGuid }
    if ($DomainName) { $azParams += '--domain-name', $DomainName }
    if ($DomainSid) { $azParams += '--domain-sid', $DomainSid }
    if ($EnableAlw) { $azParams += '--enable-alw', 'true' }
    if ($EnableFilesAadds) { $azParams += '--enable-files-aadds', 'true' }
    if ($EnableFilesAadkerb) { $azParams += '--enable-files-aadkerb', 'true' }
    if ($EnableFilesAdds) { $azParams += '--enable-files-adds', 'true' }
    if ($EnableLocalUser) { $azParams += '--enable-local-user', 'true' }
    if ($EncryptionKeyTypeForQueue) { $azParams += '--encryption-key-type-for-queue', $EncryptionKeyTypeForQueue }
    if ($EncryptionKeyTypeForTable) { $azParams += '--encryption-key-type-for-table', $EncryptionKeyTypeForTable }
    if ($EncryptionServices) { $azParams += '--encryption-services', $EncryptionServices }
    if ($ForestName) { $azParams += '--forest-name', $ForestName }
    if ($ImmutabilityPeriod) { $azParams += '--immutability-period', $ImmutabilityPeriod }
    if ($ImmutabilityState) { $azParams += '--immutability-state', $ImmutabilityState }
    if ($KeyExpDays) { $azParams += '--key-exp-days', $KeyExpDays }
    if ($KeyVaultFederatedClientId) { $azParams += '--key-vault-federated-client-id', $KeyVaultFederatedClientId }
    if ($KeyVaultUserIdentityId) { $azParams += '--key-vault-user-identity-id', $KeyVaultUserIdentityId }
    if ($NetBiosDomainName) { $azParams += '--net-bios-domain-name', $NetBiosDomainName }
    if ($SamAccountName) { $azParams += '--sam-account-name', $SamAccountName }
    if ($SasExp) { $azParams += '--sas-exp', $SasExp }

    Write-Host "Creating storage account '$Name' in resource group '$ResourceGroup'..." -ForegroundColor Yellow

    # Execute the Azure CLI command
    $result = & az @azParams --output json

    if ($LASTEXITCODE -eq 0) {
        $storageAccount = $result | ConvertFrom-Json

        Write-Host "✓ Storage account created successfully!" -ForegroundColor Green
        Write-Host "Storage Account Details:" -ForegroundColor Cyan
        Write-Host "  Name: $($storageAccount.name)" -ForegroundColor White
        Write-Host "  Resource Group: $($storageAccount.resourceGroup)" -ForegroundColor White
        Write-Host "  Location: $($storageAccount.location)" -ForegroundColor White
        Write-Host "  SKU: $($storageAccount.sku.name)" -ForegroundColor White
        Write-Host "  Kind: $($storageAccount.kind)" -ForegroundColor White
        Write-Host "  Creation Time: $($storageAccount.creationTime)" -ForegroundColor White

        if ($storageAccount.primaryEndpoints) {
            Write-Host "Primary Endpoints:" -ForegroundColor Cyan
            if ($storageAccount.primaryEndpoints.blob) {
                Write-Host "  Blob: $($storageAccount.primaryEndpoints.blob)" -ForegroundColor White
            }
            if ($storageAccount.primaryEndpoints.file) {
                Write-Host "  File: $($storageAccount.primaryEndpoints.file)" -ForegroundColor White
            }
            if ($storageAccount.primaryEndpoints.queue) {
                Write-Host "  Queue: $($storageAccount.primaryEndpoints.queue)" -ForegroundColor White
            }
            if ($storageAccount.primaryEndpoints.table) {
                Write-Host "  Table: $($storageAccount.primaryEndpoints.table)" -ForegroundColor White
            }
        }
    } else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE"
    }

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
