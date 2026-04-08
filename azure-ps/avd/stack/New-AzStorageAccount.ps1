<#
.SYNOPSIS
    Creates a new Azure Storage Account.

.DESCRIPTION
    This script creates a new Azure Storage Account with the specified parameters.
    Uses the New-AzStorageAccount cmdlet from the Az.Storage module.

.PARAMETER ResourceGroup
    The name of the Resource Group where the Storage Account will be created.

.PARAMETER Name
    The name of the Storage Account.

.PARAMETER SkuName
    The SKU of the Storage Account.

.PARAMETER Location
    The location of the Storage Account.

.PARAMETER Kind
    The kind of the Storage Account.

.PARAMETER AccessTier
    The access tier of the Storage Account.

.PARAMETER CustomDomainName
    The custom domain name of the Storage Account.

.PARAMETER UseSubDomain
    Indicates if the Storage Account uses a subdomain.

.PARAMETER Tags
    The tags of the Storage Account.

.PARAMETER EnableHttpsTrafficOnly
    Indicates if the Storage Account enables HTTPS traffic only.

.PARAMETER AssignIdentity
    Indicates if the Storage Account assigns an identity.

.PARAMETER UserAssignedIdentityId
    The user-assigned identity ID of the Storage Account.

.PARAMETER IdentityType
    The identity type of the Storage Account.

.PARAMETER KeyVaultUserAssignedIdentityId
    The user-assigned identity ID of the Key Vault.

.PARAMETER KeyVaultFederatedClientId
    The federated client ID of the Key Vault.

.PARAMETER KeyName
    The name of the key.

.PARAMETER KeyVersion
    The version of the key.

.PARAMETER KeyVaultUri
    The URI of the Key Vault.

.PARAMETER EnableSftp
    Indicates if the Storage Account enables SFTP.

.PARAMETER EnableLocalUser
    Indicates if the Storage Account enables local user.

.PARAMETER EnableHierarchicalNamespace
    Indicates if the Storage Account enables hierarchical namespace.

.PARAMETER EnableLargeFileShare
    Indicates if the Storage Account enables large file share.

.PARAMETER PublishMicrosoftEndpoint
    Indicates if the Storage Account publishes the Microsoft endpoint.

.PARAMETER PublishInternetEndpoint
    Indicates if the Storage Account publishes the Internet endpoint.

.PARAMETER EnableureActiveDirectoryDomainServicesForFile
    Indicates if the Storage Account enables Active Directory Domain Services for file.

.PARAMETER ActiveDirectoryDomainName
    The name of the Active Directory domain.

.PARAMETER ActiveDirectoryDomainGuid
    The GUID of the Active Directory domain.

.PARAMETER EncryptionKeyTypeForTable
    The encryption key type for table.

.PARAMETER EncryptionKeyTypeForQueue
    The encryption key type for queue.

.PARAMETER RequireInfrastructureEncryption
    Indicates if the Storage Account requires infrastructure encryption.

.PARAMETER KeyExpirationPeriodInDay
    The key expiration period in days.

.PARAMETER AllowBlobPublicAccess
    Indicates if the Storage Account allows blob public access.

.PARAMETER MinimumTlsVersion
    The minimum TLS version.

.PARAMETER AllowSharedKeyAccess
    Indicates if the Storage Account allows shared key access.

.PARAMETER EnableNfsV3
    Indicates if the Storage Account enables NFS V3.

.PARAMETER AllowCrossTenantReplication
    Indicates if the Storage Account allows cross-tenant replication.

.PARAMETER DefaultSharePermission
    The default share permission.

.PARAMETER EdgeZone
    The edge zone.

.PARAMETER PublicNetworkAccess
    The public network access.

.PARAMETER EnableAccountLevelImmutability
    Indicates if the Storage Account enables account-level immutability.

.PARAMETER ImmutabilityPeriod
    The immutability period.

.PARAMETER ImmutabilityPolicyState
    The immutability policy state.

.PARAMETER AllowedCopyScope
    The allowed copy scope.

.PARAMETER DnsEndpointType
    The DNS endpoint type.

.PARAMETER RoutingChoice
    The routing choice.

.EXAMPLE
    .\New-AzStorageAccount.ps1 -ResourceGroup "MyResourceGroup" -Name "MyStorageAccount" -SkuName "Standard_LRS" -Location "eastus" -Kind "StorageV2"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.Storage

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.storage/new-azstorageaccount?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Storage
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage = "The name of the Resource Group where the Storage Account will be created.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The SKU of the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Standard_LRS',
        'Standard_GRS',
        'Standard_RAGRS',
        'Standard_ZRS',
        'Premium_LRS',
        'Premium_ZRS',
        'Standard_GZRS',
        'Standard_RAGZRS'
    )]
    [string]$SkuName,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the Storage Account will be created.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral',
        'asia', 'asiapacific', 'australia', 'brazil',
        'canada', 'europe', 'france', 'germany',
        'global', 'india', 'japan', 'korea',
        'norway', 'singapore', 'southafrica', 'sweden',
        'switzerland', 'unitedstates', 'northcentralus', 'westus',
        'japanwest', 'centraluseuap', 'eastus2euap', 'westcentralus',
        'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast',
        'koreasouth', 'southindia', 'westindia', 'canadaeast',
        'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest',
        'ukwest', 'uaecentral', 'brazilsoutheast'
    )]
    [string]$Location,

    [Parameter(Mandatory=$false, HelpMessage = "The kind of the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'StorageV2',
        'StorageV1',
        'BlobStorage',
        'FileStorage',
        'BlockBlobStorage',
        'Storage'
    )]
    [string]$Kind,

    [Parameter(Mandatory=$false, HelpMessage = "The access tier of the Storage Account (Hot or Cool).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Hot',
        'Cool'
    )]
    [string]$AccessTier,

    [Parameter(Mandatory=$false, HelpMessage = "The custom domain name of the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomDomainName,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account uses a subdomain.")]
    [ValidateNotNullOrEmpty()]
    [bool]$UseSubDomain,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account enables HTTPS traffic only.")]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableHttpsTrafficOnly,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account assigns an identity.")]
    [ValidateNotNullOrEmpty()]
    [switch]$AssignIdentity,

    [Parameter(Mandatory=$false, HelpMessage = "The user-assigned identity ID of the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserAssignedIdentityId,

    [Parameter(Mandatory=$false, HelpMessage = "The identity type of the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'SystemAssigned',
        'UserAssigned',
        'SystemAssigned,UserAssigned'
    )]
    [string]$IdentityType,

    [Parameter(Mandatory=$false, HelpMessage = "The user-assigned identity ID of the Key Vault.")]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultUserAssignedIdentityId,

    [Parameter(Mandatory=$false, HelpMessage = "The federated client ID of the Key Vault.")]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultFederatedClientId,

    [Parameter(Mandatory=$false, HelpMessage = "The name of the encryption key.")]
    [ValidateNotNullOrEmpty()]
    [string]$KeyName,

    [Parameter(Mandatory=$false, HelpMessage = "The version of the encryption key.")]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVersion,

    [Parameter(Mandatory=$false, HelpMessage = "The URI of the Key Vault.")]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultUri,

    #type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[PSNetworkRuleSet]$NetworkRuleSet,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account enables SFTP.")]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableSftp,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account enables local user.")]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableLocalUser,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account enables hierarchical namespace.")]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableHierarchicalNamespace,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account enables large file share.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableLargeFileShare,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account publishes the Microsoft endpoint.")]
    [ValidateNotNullOrEmpty()]
    [bool]$PublishMicrosoftEndpoint,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account publishes the Internet endpoint.")]
    [ValidateNotNullOrEmpty()]
    [bool]$PublishInternetEndpoint,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account enables Active Directory Domain Services for file.")]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableureActiveDirectoryDomainServicesForFile,

    [Parameter(Mandatory=$false, HelpMessage = "The name of the Active Directory domain.")]
    [ValidateNotNullOrEmpty()]
    [string]$ActiveDirectoryDomainName,

    [Parameter(Mandatory=$false, HelpMessage = "The GUID of the Active Directory domain.")]
    [ValidateNotNullOrEmpty()]
    [string]$ActiveDirectoryDomainGuid,

    [Parameter(Mandatory=$false, HelpMessage = "The encryption key type for table storage.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Service',
        'Account'
    )]
    [string]$EncryptionKeyTypeForTable,

    [Parameter(Mandatory=$false, HelpMessage = "The encryption key type for queue storage.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Service',
        'Account'
    )]
    [string]$EncryptionKeyTypeForQueue,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account requires infrastructure encryption.")]
    [ValidateNotNullOrEmpty()]
    [switch]$RequireInfrastructureEncryption,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[timespan]$SasExpirationPeriod,

    [Parameter(Mandatory=$false, HelpMessage = "The key expiration period in days.")]
    [ValidateNotNullOrEmpty()]
    [int]$KeyExpirationPeriodInDay,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account allows blob public access.")]
    [ValidateNotNullOrEmpty()]
    [bool]$AllowBlobPublicAccess,

    [Parameter(Mandatory=$false, HelpMessage = "The minimum TLS version for the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'TLS1_0',
        'TLS1_1',
        'TLS1_2'
    )]
    [string]$MinimumTlsVersion,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account allows shared key access.")]
    [ValidateNotNullOrEmpty()]
    [bool]$AllowSharedKeyAccess,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account enables NFS V3.")]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableNfsV3,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account allows cross-tenant replication.")]
    [ValidateNotNullOrEmpty()]
    [bool]$AllowCrossTenantReplication,

    [Parameter(Mandatory=$false, HelpMessage = "The default share permission for Azure Files.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'None',
        'StorageFileDataSmbShareContributor',
        'StorageFileDataSmbShareReader',
        'StorageFileDataSmbShareElevatedContributor'
    )]
    [string]$DefaultSharePermission,

    [Parameter(Mandatory=$false, HelpMessage = "The edge zone for the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone,

    [Parameter(Mandatory=$false, HelpMessage = "The public network access setting for the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Disabled',
        'Enabled'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false, HelpMessage = "Indicates if the Storage Account enables account-level immutability.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableAccountLevelImmutability,

    [Parameter(Mandatory=$false, HelpMessage = "The immutability period in days.")]
    [ValidateNotNullOrEmpty()]
    [int]$ImmutabilityPeriod,

    [Parameter(Mandatory=$false, HelpMessage = "The immutability policy state.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImmutabilityPolicyState,

    [Parameter(Mandatory=$false, HelpMessage = "The allowed copy scope for the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'PrivateLink',
        'AAD'
    )]
    [string]$AllowedCopyScope,

    [Parameter(Mandatory=$false, HelpMessage = "The DNS endpoint type for the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Standard',
        'AzureDnsZone'
    )]
    [string]$DnsEndpointType,

    [Parameter(Mandatory=$false, HelpMessage = "The routing choice for the Storage Account.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'MicrosoftRouting',
        'InternetRouting'
    )]
    [string]$RoutingChoice
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Splatting parameters for better readability
    $parameters = @{
        ResourceGroupName = $ResourceGroup
        Name              = $Name
        SkuName           = $SkuName
        Location          = $Location
    }

    if ($Kind) {
        $parameters['Kind'] = $Kind
    }

    if ($AccessTier) {
        $parameters['AccessTier'] = $AccessTier
    }

    if ($CustomDomainName) {
        $parameters['CustomDomainName'] = $CustomDomainName
    }

    if ($UseSubDomain) {
        $parameters['UseSubDomain'] = $UseSubDomain
    }

    if ($Tags) {
        $parameters['Tag'] = $Tags
    }

    if ($EnableHttpsTrafficOnly) {
        $parameters['EnableHttpsTrafficOnly'] = $EnableHttpsTrafficOnly
    }

    if ($AssignIdentity) {
        $parameters['AssignIdentity'] = $AssignIdentity
    }

    if ($UserAssignedIdentityId) {
        $parameters['UserAssignedIdentityId'] = $UserAssignedIdentityId
    }

    if ($IdentityType) {
        $parameters['IdentityType'] = $IdentityType
    }

    if ($KeyVaultUserAssignedIdentityId) {
        $parameters['KeyVaultUserAssignedIdentityId'] = $KeyVaultUserAssignedIdentityId
    }

    if ($KeyVaultFederatedClientId) {
        $parameters['KeyVaultFederatedClientId'] = $KeyVaultFederatedClientId
    }

    if ($KeyName) {
        $parameters['KeyName'] = $KeyName
    }

    if ($KeyVersion) {
        $parameters['KeyVersion'] = $KeyVersion
    }

    if ($KeyVaultUri) {
        $parameters['KeyVaultUri'] = $KeyVaultUri
    }

    #if ($NetworkRuleSet) {
    #    $parameters['NetworkRuleSet'] = $NetworkRuleSet
    #}

    if ($EnableSftp) {
        $parameters['EnableSftp'] = $EnableSftp
    }

    if ($EnableLocalUser) {
        $parameters['EnableLocalUser'] = $EnableLocalUser
    }

    if ($EnableHierarchicalNamespace) {
        $parameters['EnableHierarchicalNamespace'] = $EnableHierarchicalNamespace
    }

    if ($EnableLargeFileShare) {
        $parameters['EnableLargeFileShare'] = $EnableLargeFileShare
    }

    if ($PublishMicrosoftEndpoint) {
        $parameters['PublishMicrosoftEndpoint'] = $PublishMicrosoftEndpoint
    }

    if ($PublishInternetEndpoint) {
        $parameters['PublishInternetEndpoint'] = $PublishInternetEndpoint
    }

    if ($EnableureActiveDirectoryDomainServicesForFile) {
        $parameters['EnableActiveDirectoryDomainServicesForFile'] = $EnableureActiveDirectoryDomainServicesForFile
    }

    if ($ActiveDirectoryDomainName) {
        $parameters['ActiveDirectoryDomainName'] = $ActiveDirectoryDomainName
    }

    if ($ActiveDirectoryDomainGuid) {
        $parameters['ActiveDirectoryDomainGuid'] = $ActiveDirectoryDomainGuid
    }

    if ($EncryptionKeyTypeForTable) {
        $parameters['EncryptionKeyTypeForTable'] = $EncryptionKeyTypeForTable
    }

    if ($EncryptionKeyTypeForQueue) {
        $parameters['EncryptionKeyTypeForQueue'] = $EncryptionKeyTypeForQueue
    }

    if ($RequireInfrastructureEncryption) {
        $parameters['RequireInfrastructureEncryption'] = $RequireInfrastructureEncryption
    }

    #if ($SasExpirationPeriod) {
    #    $parameters['SasExpirationPeriod'] = $SasExpirationPeriod
    #}

    if ($KeyExpirationPeriodInDay) {
        $parameters['KeyExpirationPeriodInDay'] = $KeyExpirationPeriodInDay
    }

    if ($AllowBlobPublicAccess) {
        $parameters['AllowBlobPublicAccess'] = $AllowBlobPublicAccess
    }

    if ($MinimumTlsVersion) {
        $parameters['MinimumTlsVersion'] = $MinimumTlsVersion
    }

    if ($AllowSharedKeyAccess) {
        $parameters['AllowSharedKeyAccess'] = $AllowSharedKeyAccess
    }

    if ($EnableNfsV3) {
        $parameters['EnableNfsV3'] = $EnableNfsV3
    }

    if ($AllowCrossTenantReplication) {
        $parameters['AllowCrossTenantReplication'] = $AllowCrossTenantReplication
    }

    if ($DefaultSharePermission) {
        $parameters['DefaultSharePermission'] = $DefaultSharePermission
    }

    if ($EdgeZone) {
        $parameters['EdgeZone'] = $EdgeZone
    }

    if ($PublicNetworkAccess) {
        $parameters['PublicNetworkAccess'] = $PublicNetworkAccess
    }

    if ($EnableAccountLevelImmutability) {
        $parameters['EnableAccountLevelImmutability'] = $EnableAccountLevelImmutability
    }

    if ($ImmutabilityPeriod) {
        $parameters['ImmutabilityPeriod'] = $ImmutabilityPeriod
    }

    if ($ImmutabilityPolicyState) {
        $parameters['ImmutabilityPolicyState'] = $ImmutabilityPolicyState
    }

    if ($AllowedCopyScope) {
        $parameters['AllowedCopyScope'] = $AllowedCopyScope
    }

    if ($DnsEndpointType) {
        $parameters['DnsEndpointType'] = $DnsEndpointType
    }

    if ($RoutingChoice) {
        $parameters['RoutingChoice'] = $RoutingChoice
    }

    # Create the storage account and capture the result
    $result = New-AzStorageAccount @parameters

    # Output the result
    Write-Host "✅ Storage account created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
