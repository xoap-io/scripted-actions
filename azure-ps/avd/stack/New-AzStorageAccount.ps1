<#
.SYNOPSIS
    Creates a new Azure Storage Account.

.DESCRIPTION
    This script creates a new Azure Storage Account with the specified parameters.

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
    Indicates if the Storage Account enables ure Active Directory Domain Services for file.

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

.PARAMETER SasExpirationPeriod
    The SAS expiration period.

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

    This command creates a new ure Storage Account named 'MyStorageAccount' in the 'MyResourceGroup' Resource Group located in the 'eastus' region with the 'Standard_LRS' SKU and 'StorageV2' kind.

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.storage

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.storage/new-azstorageaccount?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
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

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brilsouth', 'israelcentral', 'qatarcentral',
        'asia', 'asiapacific', 'australia', 'bril',
        'canada', 'europe', 'france', 'germany',
        'global', 'india', 'japan', 'korea',
        'norway', 'singapore', 'southafrica', 'sweden',
        'switzerland', 'unitedstates', 'northcentralus', 'westus',
        'japanwest', 'centraluseuap', 'eastus2euap', 'westcentralus',
        'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast',
        'koreasouth', 'southindia', 'westindia', 'canadaeast',
        'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest',
        'ukwest', 'uaecentral', 'brilsoutheast'
    )]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'StorageV2',
        'StorageV1',
        'BlobStorage',
        'FileStorage',
        'BlockBlobStorage',
        'Storage', 'StorageV2',
        'StorageV2Blob',
        'StorageV2File',
        'StorageV2BlockBlob',
        'StorageV2Storage',
        'StorageV2StorageV2',
        'StorageV2StorageV2Blob',
        'StorageV2StorageV2File',
        'StorageV2StorageV2BlockBlob',
        'StorageV2StorageV2Storage'
    )]
    [string]$Kind,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Hot', 
        'Cool'
    )]
    [string]$AccessTier,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CustomDomainName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$UseSubDomain,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableHttpsTrafficOnly,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$AssignIdentity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$UserAssignedIdentityId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'SystemAssigned', 
        'UserAssigned', 
        'SystemAssigned, UserAssigned'
    )]
    [string]$IdentityType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultUserAssignedIdentityId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultFederatedClientId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVersion,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$KeyVaultUri,

    #type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[PSNetworkRuleSet]$NetworkRuleSet,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableSftp,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableLocalUser,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableHierarchicalNamespace,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableLargeFileShare,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$PublishMicrosoftEndpoint,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$PublishInternetEndpoint,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableureActiveDirectoryDomainServicesForFile,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ActiveDirectoryDomainName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ActiveDirectoryDomainGuid,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Service',
        'Account'
    )]
    [string]$EncryptionKeyTypeForTable,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Service',
        'Account'
    )]
    [string]$EncryptionKeyTypeForQueue,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$RequireInfrastructureEncryption,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[timespan]$SasExpirationPeriod,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$KeyExpirationPeriodInDay,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$AllowBlobPublicAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'TLS1_0',
        'TLS1_1',
        'TLS1_2'
    )]
    [string]$MinimumTlsVersion,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$AllowSharedKeyAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableNfsV3,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$AllowCrossTenantReplication,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('None', 'StorageFileDataSmbShareContributor', 'StorageFileDataSmbShareReader', 'StorageFileDataSmbShareElevatedContributor')]
    [string]$DefaultSharePermission,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Disabled',
        'Enabled'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableAccountLevelImmutability,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$ImmutabilityPeriod,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ImmutabilityPolicyState,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'PrivateLink',
        'AAD'
    )]
    [string]$AllowedCopyScope,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Standard',
        'AzureDnsZone'
    )]
    [string]$DnsEndpointType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'MicrosoftRouting',
        'InternetRouting'
    )]
    [string]$RoutingChoice
)

# Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

try {
    # Splatting parameters for better readability
    $parameters = @{
        ResourceGroup = $ResourceGroup
        Name              = $Name
        SkuName           = $SkuName
        Location          = $Location
        Kind              = $Kind
        AccessTier        = $AccessTier
    }

    if ($CustomDomainName) {
        $parameters['CustomDomainName'] = $CustomDomainName
    }

    if ($UseSubDomain) {
        $parameters['UseSubDomain'] = $UseSubDomain
    }

    if ($Tags) {
        $parameters['Tag'], $Tags
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

    # Create the virtual network and capture the result
    $result = New-AzStorageAccount @parameters

    # Output the result
    Write-Output "Storage account created successfully:"
    Write-Output $result

} catch [System.Exception] {
    # Write the error to the console
    Write-Error "Failed to create the Storage account: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
