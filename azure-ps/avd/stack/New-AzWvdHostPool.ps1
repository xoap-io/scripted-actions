<#
.SYNOPSIS
    Creates a new host pool in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new host pool in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER Name
    The name of the host pool.

.PARAMETER ResourceGroupName
    The name of the resource group.

.PARAMETER HostPoolType
    The type of the host pool.

.PARAMETER LoadBalancerType
    The type of the load balancer.

.PARAMETER PreferredAppGroupType
    The preferred app group type.

.PARAMETER Location
    The location of the host pool.

.PARAMETER AgentUpdateMaintenanceWindow
    The maintenance window properties for agent updates.

.PARAMETER AgentUpdateMaintenanceWindowTimeZone
    The time zone for the agent update maintenance window.

.PARAMETER AgentUpdateType
    The type of agent update.

.PARAMETER AgentUpdateUseSessionHostLocalTime
    Indicates if the agent update uses session host local time.

.PARAMETER CustomRdpProperty
    The custom RDP property.

.PARAMETER Description
    The description of the host pool.

.PARAMETER ExpirationTime
    The expiration time for the host pool.

.PARAMETER FriendlyName
    The friendly name of the host pool.

.PARAMETER IdentityType
    The identity type of the host pool.

.PARAMETER Kind
    The kind of the host pool.

.PARAMETER ManagedBy
    The managed by property of the host pool.

.PARAMETER MaxSessionLimit
    The maximum session limit.

.PARAMETER PersonalDesktopAssignmentType
    The personal desktop assignment type.

.PARAMETER PlanName
    The plan name of the host pool.

.PARAMETER PlanProduct
    The plan product of the host pool.

.PARAMETER PlanPromotionCode
    The plan promotion code of the host pool.

.PARAMETER PlanPublisher
    The plan publisher of the host pool.

.PARAMETER PlanVersion
    The plan version of the host pool.

.PARAMETER PublicNetworkAccess
    The public network access setting.

.PARAMETER RegistrationInfoToken
    The registration info token.

.PARAMETER RegistrationTokenOperation
    The registration token operation.

.PARAMETER Ring
    The ring number.

.PARAMETER SkuCapacity
    The SKU capacity.

.PARAMETER SkuFamily
    The SKU family.

.PARAMETER SkuName
    The SKU name.

.PARAMETER SkuSize
    The SKU size.

.PARAMETER SkuTier
    The SKU tier.

.PARAMETER SsoClientId
        The SSO client ID.

.PARAMETER SsoClientSecretKeyVaultPath
The SSO client secret key vault path.

.PARAMETER SsoSecretType
    The SSO secret type.

.PARAMETER SsoadfsAuthority
    The SSO ADFS authority.

.PARAMETER StartVMOnConnect
    Indicates if the VM should start on connect.

.PARAMETER Tags
    The tags for the host pool.

.PARAMETER VMTemplate
    The VM template.

.PARAMETER ValidationEnvironment
    Indicates if the host pool is a validation environment.

.EXAMPLE
    PS C:\> .\New-AzWvdHostPool.ps1 -Name "MyHostPool" -ResourceGroupName "MyResourceGroup" -HostPoolType "Pooled" -LoadBalancerType "BreadthFirst" -PreferredAppGroupType "Desktop"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdhostpool?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Pooled', 'Personal'
    )]
    [string]$HostPoolType,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'DepthFirst', 'BreadthFirst', 'Persistent'
    )]
    [string]$LoadBalancerType,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Desktop', 'None','RailApplications'
    )]
    [string]$PreferredAppGroupType,

    [Parameter(Mandatory=$true)]
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

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DesktopAppGroupName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AgentUpdateMaintenanceWindow,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AgentUpdateMaintenanceWindowTimeZone,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Default', 'Scheduled'
    )]
    [string]$AgentUpdateType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$AgentUpdateUseSessionHostLocalTime,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CustomRdpProperty,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [datetime]$ExpirationTime,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,


    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$IdentityType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Kind = "DesktopVirtualizationHostPools",

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ManagedBy,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$MaxSessionLimit = 10,


    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Direct', 
        'Automatic'
    )]
    [string]$PersonalDesktopAssignmentType,

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
    [string]$PlanVersion,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Disabled', 'Enabled', 'EnabledForClientsOnly', 'EnabledForSessionHostsOnly'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationInfoToken,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Delete', 'None', 'Update'
    )]
    [string]$RegistrationTokenOperation,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$Ring,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$SkuCapacity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuFamily,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuSize,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuTier,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientSecretKeyVaultPath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoSecretType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoadfsAuthority,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$StartVMOnConnect,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VMTemplate,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$ValidationEnvironment
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name                  = $Name
    ResourceGroupName     = $ResourceGroupName
    HostPoolType          = $HostPoolType
    LoadBalancerType      = $LoadBalancerType
    PreferredAppGroupType = $PreferredAppGroupType
    Location              = $Location
}

if ($DesktopAppGroupName) {
    $parameters['DesktopAppGroupName'], $DesktopAppGroupName
}

if ($WorkspaceName) {
    $parameters['WorkspaceName'], $WorkspaceName
}

if ($AgentUpdateMaintenanceWindow) {
    $parameters['AgentUpdateMaintenanceWindow'], $AgentUpdateMaintenanceWindow
}

if ($AgentUpdateMaintenanceWindowTimeZone) {
    $parameters['AgentUpdateMaintenanceWindowTimeZone'], $AgentUpdateMaintenanceWindowTimeZone
}

if ($AgentUpdateType) {
    $parameters['AgentUpdateType'], $AgentUpdateType
}

if ($AgentUpdateUseSessionHostLocalTime) {
    $parameters['AgentUpdateUseSessionHostLocalTime'], $AgentUpdateUseSessionHostLocalTime
}

if ($CustomRdpProperty) {
    $parameters['CustomRdpProperty'], $CustomRdpProperty
}

if ($Description) {
    $parameters['Description'], $Description
}

if ($ExpirationTime) {
    $parameters['ExpirationTime'], $ExpirationTime
}

if ($FriendlyName) {
    $parameters['FriendlyName'], $FriendlyName
}

if ($IdentityType) {
    $parameters['IdentityType'], $IdentityType
}

if ($Kind) {
    $parameters['Kind'], $Kind
}

if ($ManagedBy) {
    $parameters['ManagedBy'], $ManagedBy
}

if ($MaxSessionLimit) {
    $parameters['MaxSessionLimit'], $MaxSessionLimit
}

if ($PersonalDesktopAssignmentType) {
    $parameters['PersonalDesktopAssignmentType'], $PersonalDesktopAssignmentType
}

if ($PlanName) {
    $parameters['PlanName'], $PlanName
}

if ($PlanProduct) {
    $parameters['PlanProduct'], $PlanProduct
}

if ($PlanPromotionCode) {
    $parameters['PlanPromotionCode'], $PlanPromotionCode
}

if ($PlanPublisher) {
    $parameters['PlanPublisher'], $PlanPublisher
}

if ($PlanVersion) {
    $parameters['PlanVersion'], $PlanVersion
}

if ($PublicNetworkAccess) {
    $parameters['PublicNetworkAccess'], $PublicNetworkAccess
}

if ($RegistrationInfoToken) {
    $parameters['RegistrationInfoToken'], $RegistrationInfoToken
}

if ($RegistrationTokenOperation) {
    $parameters['RegistrationTokenOperation'], $RegistrationTokenOperation
}

if ($Ring) {
    $parameters['Ring'], $Ring
}

if ($SkuCapacity) {
    $parameters['SkuCapacity'], $SkuCapacity
}

if ($SkuFamily) {
    $parameters['SkuFamily'], $SkuFamily
}

if ($SkuName) {
    $parameters['SkuName'], $SkuName
}

if ($SkuSize) {
    $parameters['SkuSize'], $SkuSize
}

if ($SkuTier) {
    $parameters['SkuTier'], $SkuTier
}

if ($SsoClientId) {
    $parameters['SsoClientId'], $SsoClientId
}

if ($SsoClientSecretKeyVaultPath) {
    $parameters['SsoClientSecretKeyVaultPath'], $SsoClientSecretKeyVaultPath
}

if ($SsoSecretType) {
    $parameters['SsoSecretType'], $SsoSecretType
}

if ($SsoadfsAuthority) {
    $parameters['SsoadfsAuthority'], $SsoadfsAuthority
}

if ($StartVMOnConnect) {
    $parameters['StartVMOnConnect'], $StartVMOnConnect
}

if ($Tags) {
    $parameters['Tag'], $Tags
}

if ($VMTemplate) {
    $parameters['VMTemplate'], $VMTemplate
}

if ($ValidationEnvironment) {
    $parameters['ValidationEnvironment'], $ValidationEnvironment
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"
  
try {
    # Create the host pool and capture the result
    $result = New-AzWvdHostPool @parameters

    # Output the result
    Write-Output "Host pool created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the host pool: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
