<#
.SYNOPSIS
    Creates a new host pool in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new host pool in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER Name
    The name of the host pool.

.PARAMETER ResourceGroup
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
    PS C:\> .\New-AzWvdHostPool.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup" -HostPoolType "Pooled" -LoadBalancerType "BreadthFirst" -PreferredAppGroupType "Desktop"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdhostpool?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The type of the host pool (Pooled or Personal).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Pooled', 'Personal'
    )]
    [string]$HostPoolType,

    [Parameter(Mandatory=$true, HelpMessage = "The load balancing type (DepthFirst, BreadthFirst, or Persistent).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'DepthFirst', 'BreadthFirst', 'Persistent'
    )]
    [string]$LoadBalancerType,

    [Parameter(Mandatory=$true, HelpMessage = "The preferred app group type (Desktop, None, or RailApplications).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Desktop', 'None','RailApplications'
    )]
    [string]$PreferredAppGroupType,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the host pool will be created.")]
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

    [Parameter(Mandatory=$false, HelpMessage = "The name of the desktop app group.")]
    [ValidateNotNullOrEmpty()]
    [string]$DesktopAppGroupName,

    [Parameter(Mandatory=$false, HelpMessage = "The name of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceName,

    [Parameter(Mandatory=$false, HelpMessage = "The maintenance window properties for agent updates.")]
    [ValidateNotNullOrEmpty()]
    [string]$AgentUpdateMaintenanceWindow,

    [Parameter(Mandatory=$false, HelpMessage = "The time zone for the agent update maintenance window.")]
    [ValidateNotNullOrEmpty()]
    [string]$AgentUpdateMaintenanceWindowTimeZone,

    [Parameter(Mandatory=$false, HelpMessage = "The type of agent update (Default or Scheduled).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Default',
        'Scheduled'
    )]
    [string]$AgentUpdateType,

    [Parameter(Mandatory=$false, HelpMessage = "Use session host local time for agent updates.")]
    [ValidateNotNullOrEmpty()]
    [switch]$AgentUpdateUseSessionHostLocalTime,

    [Parameter(Mandatory=$false, HelpMessage = "Custom RDP property string.")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomRdpProperty,

    [Parameter(Mandatory=$false, HelpMessage = "Description of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "Expiration time for the host pool registration token.")]
    [ValidateNotNullOrEmpty()]
    [datetime]$ExpirationTime,

    [Parameter(Mandatory=$false, HelpMessage = "Friendly display name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false, HelpMessage = "The identity type of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$IdentityType,

    [Parameter(Mandatory=$false, HelpMessage = "The kind of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$Kind = "DesktopVirtualizationHostPools",

    [Parameter(Mandatory=$false, HelpMessage = "The managed by property of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$ManagedBy,

    [Parameter(Mandatory=$false, HelpMessage = "Maximum number of sessions per session host.")]
    [ValidateNotNullOrEmpty()]
    [int]$MaxSessionLimit = 10,

    [Parameter(Mandatory=$true, HelpMessage = "Personal desktop assignment type (Direct or Automatic).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Direct',
        'Automatic'
    )]
    [string]$PersonalDesktopAssignmentType,

    [Parameter(Mandatory=$false, HelpMessage = "The plan name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanName,

    [Parameter(Mandatory=$false, HelpMessage = "The plan product of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanProduct,

    [Parameter(Mandatory=$false, HelpMessage = "The plan promotion code of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPromotionCode,

    [Parameter(Mandatory=$false, HelpMessage = "The plan publisher of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPublisher,

    [Parameter(Mandatory=$false, HelpMessage = "The plan version of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanVersion,

    [Parameter(Mandatory=$false, HelpMessage = "Public network access setting for the host pool.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Disabled',
        'Enabled',
        'EnabledForClientsOnly',
        'EnabledForSessionHostsOnly'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false, HelpMessage = "The registration info token for session host enrollment.")]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationInfoToken,

    [Parameter(Mandatory=$false, HelpMessage = "The registration token operation (Delete, None, or Update).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Delete',
        'None',
        'Update'
    )]
    [string]$RegistrationTokenOperation,

    [Parameter(Mandatory=$false, HelpMessage = "The deployment ring number.")]
    [ValidateNotNullOrEmpty()]
    [int]$Ring,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU capacity.")]
    [ValidateNotNullOrEmpty()]
    [int]$SkuCapacity,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU family.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuFamily,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU name.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuName,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU size.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuSize,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU tier.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuTier,

    [Parameter(Mandatory=$false, HelpMessage = "The SSO client ID.")]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientId,

    [Parameter(Mandatory=$false, HelpMessage = "The SSO client secret key vault path.")]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientSecretKeyVaultPath,

    [Parameter(Mandatory=$false, HelpMessage = "The SSO secret type.")]
    [ValidateNotNullOrEmpty()]
    [string]$SsoSecretType,

    [Parameter(Mandatory=$false, HelpMessage = "The SSO ADFS authority.")]
    [ValidateNotNullOrEmpty()]
    [string]$SsoadfsAuthority,

    [Parameter(Mandatory=$false, HelpMessage = "Start the VM when a user connects.")]
    [ValidateNotNullOrEmpty()]
    [switch]$StartVMOnConnect,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the host pool.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false, HelpMessage = "The VM template for session hosts.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMTemplate,

    [Parameter(Mandatory=$false, HelpMessage = "Mark this host pool as a validation environment.")]
    [ValidateNotNullOrEmpty()]
    [switch]$ValidationEnvironment
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name = $Name
    ResourceGroup = $ResourceGroup
    HostPoolType = $HostPoolType
    LoadBalancerType = $LoadBalancerType
    PreferredAppGroupType = $PreferredAppGroupType
    Location = $Location
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

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
