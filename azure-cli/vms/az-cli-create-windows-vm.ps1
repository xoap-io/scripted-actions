<#
.SYNOPSIS
    Create a new Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell. The script creates a new Azure Resource Group, a new Azure VM, and a new Azure Public IP Address.
    The script also retrieves the public IP address of the VM.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    Azure CLI

.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

.PARAMETER AzLocation
    Defines the location of the Azure VM.

.PARAMETER AzImageName
    Defines the name of the Azure VM image.

.PARAMETER AzPublicIpAddressName
    Defines the name of the Azure VM public IP address.

.PARAMETER AzVmUserName
    Defines the name of the Azure VM user.

.PARAMETER AzVmUserPassword
    Defines the password of the Azure VM user.

.PARAMETER AzOpenPorts
    Defines the open ports of the Azure VM.

.PARAMETER AzVmSize
    Defines the size of the Azure VM.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$AcceleratedNetworking,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AcceptTerm,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [securestring]$AdminPassword,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AdminUsername,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Asgs,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AssignIdentity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AttachDataDisks,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AttachOsDisk,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'all',
        'password',
        'ssh'
    )]
    [string]$AuthenticationType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AvailabilitySet,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$BootDiagnosticsStorage,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CapacityReservationGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Count,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CustomData,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DataDiskCaching,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DataDiskDeleteOption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DataDiskEncryptionSets,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DataDiskSizesGb,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DisableIntegrityMonitoringAutoupgrade,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'NVMe',
        'SCSI'
    )]
    [string]$DiskControllerType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableAgent,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableAutoUpdate,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableHibernation,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableHotpatching,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnableIntegrityMonitoring,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableProxyAgent,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableSecureBoot,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableVtpm,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EncryptionAtHost,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EphemeralOsDisk,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'CacheDisk',
        'NvmeDisk'
    )]
    [string]$EphemeralOsDiskPlacement,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EvictionPolicy,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$GenerateSshKeys,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Host,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$HostGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Image,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$LicenseType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$MaxPrice,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NicDeleteOption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Nics,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NoWait,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Nsg,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NsgRule,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OsDiskCaching,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OsDiskDeleteOption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OsDiskEncryptionSet,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OsDiskName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OsDiskSecureVmDiskEncryptionSet,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OsDiskSecurityEncryptionType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OsDiskSizeGb,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OsType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PatchMode,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanProduct,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPromotionCode,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPublisher,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlatformFaultDomain,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Ppg,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Priority,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PrivateIpAddress,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpAddress,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpAddressAllocation,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpAddressDnsName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpSku,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Role,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Scope,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Secrets,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Size,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDiskRestorePoint,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceDiskRestorePointSizeGb,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceResource,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SourceResourceSize,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Specialized,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SshDestKeyPath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SshKeyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SshKeyValues,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccount,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageContainerName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageSku,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Subnet,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetAddressPrefix,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$UltraSsdEnabled,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$UseUnmanagedDisk,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$UserData,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VCpusAvailable,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VCpusPerCore,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Validate,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Vmss,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VnetAddressPrefix,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VnetName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Workspace,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Zone
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

# Create a new Azure VM

$parameters = @{
    '--resource-group' = $ResourceGroup
    '--name' = $Name
}

if ($AcceleratedNetworking) {
    $parameters += '--accelerated-networking', $AcceleratedNetworking
}

if ($AcceptTerm) {
    $parameters += '--accept-term', $AcceptTerm
}

if ($AdminPassword) {
    $parameters += '--admin-password', $AdminPassword
}

if ($AdminUsername) {
    $parameters += '--admin-username', $AdminUsername
}

if ($Asgs) {
    $parameters += '--asgs', $Asgs
}

if ($AssignIdentity) {
    $parameters += '--assign-identity', $AssignIdentity
}

if ($AttachDataDisks) {
    $parameters += '--attach-data-disks', $AttachDataDisks
}

if ($AttachOsDisk) {
    $parameters += '--attach-os-disk', $AttachOsDisk
}

if ($AuthenticationType) {
    $parameters += '--authentication-type', $AuthenticationType
}

if ($AvailabilitySet) {
    $parameters += '--availability-set', $AvailabilitySet
}

if ($BootDiagnosticsStorage) {
    $parameters += '--boot-diagnostics-storage', $BootDiagnosticsStorage
}

if ($CapacityReservationGroup) {
    $parameters += '--capacity-reservation-group', $CapacityReservationGroup
}

if ($ComputerName) {
    $parameters += '--computer-name', $ComputerName
}

if ($Count) {
    $parameters += '--count', $Count
}

if ($CustomData) {
    $parameters += '--custom-data', $CustomData
}

if ($DataDiskCaching) {
    $parameters += '--data-disk-caching', $DataDiskCaching
}

if ($DataDiskDeleteOption) {
    $parameters += '--data-disk-delete-option', $DataDiskDeleteOption
}

if ($DataDiskEncryptionSets) {
    $parameters += '--data-disk-encryption-sets', $DataDiskEncryptionSets
}

if ($DataDiskSizesGb) {
    $parameters += '--data-disk-sizes-gb', $DataDiskSizesGb
}

if ($DisableIntegrityMonitoringAutoupgrade) {
    $parameters += '--disable-integrity-monitoring-autoupgrade', $DisableIntegrityMonitoringAutoupgrade
}

if ($DiskControllerType) {
    $parameters += '--disk-controller-type', $DiskControllerType
}

if ($EdgeZone) {
    $parameters += '--edge-zone', $EdgeZone
}

if ($EnableAgent) {
    $parameters += '--enable-agent', $EnableAgent
}

if ($EnableAutoUpdate) {
    $parameters += '--enable-auto-update', $EnableAutoUpdate
}

if ($EnableHibernation) {
    $parameters += '--enable-hibernation', $EnableHibernation
}

if ($EnableHotpatching) {
    $parameters += '--enable-hotpatching', $EnableHotpatching
}

if ($EnableIntegrityMonitoring) {
    $parameters += '--enable-integrity-monitoring', $EnableIntegrityMonitoring
}

if ($EnableProxyAgent) {
    $parameters += '--enable-proxy-agent', $EnableProxyAgent
}

if ($EnableSecureBoot) {
    $parameters += '--enable-secure-boot', $EnableSecureBoot
}

if ($EnableVtpm) {
    $parameters += '--enable-vtpm', $EnableVtpm
}

if ($EncryptionAtHost) {
    $parameters += '--encryption-at-host', $EncryptionAtHost
}

if ($EphemeralOsDisk) {
    $parameters += '--ephemeral-os-disk', $EphemeralOsDisk
}

if ($EphemeralOsDiskPlacement) {
    $parameters += '--ephemeral-os-disk-placement', $EphemeralOsDiskPlacement
}

if ($EvictionPolicy) {
    $parameters += '--eviction-policy', $EvictionPolicy
}

if ($GenerateSshKeys) {
    $parameters += '--generate-ssh-keys', $GenerateSshKeys
}

if ($Host) {
    $parameters += '--host', $Host
}

if ($HostGroup) {
    $parameters += '--host-group', $HostGroup
}

if ($Image) {
    $parameters += '--image', $Image
}

if ($LicenseType) {
    $parameters += '--license-type', $LicenseType
}

if ($Location) {
    $parameters += '--location', $Location
}

if ($MaxPrice) {
    $parameters += '--max-price', $MaxPrice
}

if ($NicDeleteOption) {
    $parameters += '--nic-delete-option', $NicDeleteOption
}

if ($Nics) {
    $parameters += '--nics', $Nics
}

if ($NoWait) {
    $parameters += '--no-wait', $NoWait
}

if ($Nsg) {
    $parameters += '--nsg', $Nsg
}

if ($NsgRule) {
    $parameters += '--nsg-rule', $NsgRule
}

if ($OsDiskCaching) {
    $parameters += '--os-disk-caching', $OsDiskCaching
}

if ($OsDiskDeleteOption) {
    $parameters += '--os-disk-delete-option', $OsDiskDeleteOption
}

if ($OsDiskEncryptionSet) {
    $parameters += '--os-disk-encryption-set', $OsDiskEncryptionSet
}

if ($OsDiskName) {
    $parameters += '--os-disk-name', $OsDiskName
}

if ($OsDiskSecureVmDiskEncryptionSet) {
    $parameters += '--os-disk-secure-vm-disk-encryption-set', $OsDiskSecureVmDiskEncryptionSet
}

if ($OsDiskSecurityEncryptionType) {
    $parameters += '--os-disk-security-encryption-type', $OsDiskSecurityEncryptionType
}

if ($OsDiskSizeGb) {
    $parameters += '--os-disk-size-gb', $OsDiskSizeGb
}

if ($OsType) {
    $parameters += '--os-type', $OsType
}

if ($PatchMode) {
    $parameters += '--patch-mode', $PatchMode
}

if ($PlanName) {
    $parameters += '--plan-name', $PlanName
}

if ($PlanProduct) {
    $parameters += '--plan-product', $PlanProduct
}

if ($PlanPromotionCode) {
    $parameters += '--plan-promotion-code', $PlanPromotionCode
}

if ($PlanPublisher) {
    $parameters += '--plan-publisher', $PlanPublisher
}

if ($PlatformFaultDomain) {
    $parameters += '--platform-fault-domain', $PlatformFaultDomain
}

if ($Ppg) {
    $parameters += '--ppg', $Ppg
}

if ($Priority) {
    $parameters += '--priority', $Priority
}

if ($PrivateIpAddress) {
    $parameters += '--private-ip-address', $PrivateIpAddress
}

if ($PublicIpAddress) {
    $parameters += '--public-ip-address', $PublicIpAddress
}

if ($PublicIpAddressAllocation) {
    $parameters += '--public-ip-address-allocation', $PublicIpAddressAllocation
}

if ($PublicIpAddressDnsName) {
    $parameters += '--public-ip-address-dns-name', $PublicIpAddressDnsName
}

if ($PublicIpSku) {
    $parameters += '--public-ip-sku', $PublicIpSku
}

if ($Role) {
    $parameters += '--role', $Role
}

if ($Scope) {
    $parameters += '--scope', $Scope
}

if ($Secrets) {
    $parameters += '--secrets', $Secrets
}

if ($SecurityType) {
    $parameters += '--security-type', $SecurityType
}

if ($Size) {
    $parameters += '--size', $Size
}

if ($SourceDiskRestorePoint) {
    $parameters += '--source-disk-restore-point', $SourceDiskRestorePoint
}

if ($SourceDiskRestorePointSizeGb) {
    $parameters += '--source-disk-restore-point-size-gb', $SourceDiskRestorePointSizeGb
}

if ($SourceResource) {
    $parameters += '--source-resource', $SourceResource
}

if ($SourceResourceSize) {
    $parameters += '--source-resource-size', $SourceResourceSize
}

if ($Specialized) {
    $parameters += '--specialized', $Specialized
}

if ($SshDestKeyPath) {
    $parameters += '--ssh-dest-key-path', $SshDestKeyPath
}

if ($SshKeyName) {
    $parameters += '--ssh-key-name', $SshKeyName
}

if ($SshKeyValues) {
    $parameters += '--ssh-key-values', $SshKeyValues
}

if ($StorageAccount) {
    $parameters += '--storage-account', $StorageAccount
}

if ($StorageContainerName) {
    $parameters += '--storage-container-name', $StorageContainerName
}

if ($StorageSku) {
    $parameters += '--storage-sku', $StorageSku
}

if ($Subnet) {
    $parameters += '--subnet', $Subnet
}

if ($SubnetAddressPrefix) {
    $parameters += '--subnet-address-prefix', $SubnetAddressPrefix
}

if ($Tags) {
    $parameters += '--tags', $Tags
}

if ($UltraSsdEnabled) {
    $parameters += '--ultra-ssd-enabled', $UltraSsdEnabled
}

if ($UseUnmanagedDisk) {
    $parameters += '--use-unmanaged-disk', $UseUnmanagedDisk
}

if ($UserData) {
    $parameters += '--user-data', $UserData
}

if ($VCpusAvailable) {
    $parameters += '--v-cpus-available', $VCpusAvailable
}

if ($VCpusPerCore) {
    $parameters += '--v-cpus-per-core', $VCpusPerCore
}

if ($Validate) {
    $parameters += '--validate', $Validate
}

if ($Vmss) {
    $parameters += '--vmss', $Vmss
}

if ($VnetAddressPrefix) {
    $parameters += '--vnet-address-prefix', $VnetAddressPrefix
}

if ($VnetName) {
    $parameters += '--vnet-name', $VnetName
}

if ($Workspace) {
    $parameters += '--workspace', $Workspace
}

if ($Zone) {
    $parameters += '--zone', $Zone
}

try {
    # Create a new Azure VM
    az vm create @parameters

    # Output the result
    Write-Output "Azure VM created successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"


    Write-Error "Failed to create the Azure VM: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
