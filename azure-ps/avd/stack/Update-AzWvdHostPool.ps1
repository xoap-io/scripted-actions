<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Host Pool.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Host Pool.

.PARAMETER Name
    The name of the host pool.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER AgentUpdateMaintenanceWindow
    The maintenance window for agent updates.

.PARAMETER AgentUpdateMaintenanceWindowTimeZone
    The time zone for the maintenance window.

.PARAMETER AgentUpdateType
    The type of agent update.

.PARAMETER AgentUpdateUseSessionHostLocalTime
    Specifies whether to use the session host local time for updates.

.PARAMETER CustomRdpProperty
    Custom RDP properties.

.PARAMETER Description
    The description of the host pool.

.PARAMETER FriendlyName
    The friendly name of the host pool.

.PARAMETER LoadBalancerType
    The type of load balancer.

.PARAMETER MaxSessionLimit
    The maximum session limit.

.PARAMETER PersonalDesktopAssignmentType
    The type of personal desktop assignment.

.PARAMETER PreferredAppGroupType
    The preferred application group type.

.PARAMETER PublicNetworkAccess
    Specifies whether the host pool is accessible over a public network.

.PARAMETER RegistrationInfoExpirationTime
    The expiration time for registration info.

.PARAMETER RegistrationInfoRegistrationTokenOperation
    The registration token operation.

.PARAMETER Ring
    The ring number.

.PARAMETER SsoClientId
    The client ID for SSO.

.PARAMETER SsoClientSecretKeyVaultPath
    The key vault path for the SSO client secret.

.PARAMETER SsoSecretType
    The type of SSO secret.

.PARAMETER SsoadfsAuthority
    The ADFS authority for SSO.

.PARAMETER StartVMOnConnect
    Specifies whether to start the VM on connect.

.PARAMETER Tag
    A hashtable of tags to assign to the host pool.

.PARAMETER VMTemplate
    The VM template.

.PARAMETER ValidationEnvironment
    Specifies whether this is a validation environment.

.EXAMPLE
    PS C:\> .\Update-AzWvdHostPool.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup" -Description "Updated Description"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdhostpool?view=azps-12.3.0

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
    [string]$ResourceGroup,

    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[string]$AgentUpdateMaintenanceWindow,

    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[string]$AgentUpdateMaintenanceWindowTimeZone,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Default",
        "Scheduled"
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
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "BreadthFirst",
        "DepthFirst",
        'Persistent'
    )]
    [string]$LoadBalancerType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$MaxSessionLimit,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Automatic",
        "Direct"
    )]
    [string]$PersonalDesktopAssignmentType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Desktop",
        "None",
        'RailApplications'
    )]
    [string]$PreferredAppGroupType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Disabled",
        "Enabled",
        "EnabledForClientsOnly",
        'EnabledForSessionHostOnly'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [DateTime]$RegistrationInfoExpirationTime,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Delete",
        "None",
        "Update"
    )]
    [String]$RegistrationInfoRegistrationTokenOperation,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$Ring,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientSecretKeyVaultPath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Certificate",
        "CertificateInKeyVault",
        "SharedKey",
        "SharedKeyInKeyVault"
    )]
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

# Splatting parameters for better readability
$parameters = @{
    Name                = $Name
    ResourceGroup   = $ResourceGroup
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

if ($FriendlyName) {
    $parameters['FriendlyName'], $FriendlyName
}

if ($LoadBalancerType) {
    $parameters['LoadBalancerType'], $LoadBalancerType
}

if ($MaxSessionLimit) {
    $parameters['MaxSessionLimit'], $MaxSessionLimit
}

if ($PersonalDesktopAssignmentType) {
    $parameters['PersonalDesktopAssignmentType'], $PersonalDesktopAssignmentType
}

if ($PreferredAppGroupType) {
    $parameters['PreferredAppGroupType'], $PreferredAppGroupType
}

if ($PublicNetworkAccess) {
    $parameters['PublicNetworkAccess'], $PublicNetworkAccess
}

if ($RegistrationInfoExpirationTime) {
    $parameters['RegistrationInfoExpirationTime'], $RegistrationInfoExpirationTime
}

if ($RegistrationInfoRegistrationTokenOperation) {
    $parameters['RegistrationInfoRegistrationTokenOperation'], $RegistrationInfoRegistrationTokenOperation
}

if ($Ring) {
    $parameters['Ring'], $Ring
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
    # Update the Azure Virtual Desktop Host Pool and capture the result
    $result = Update-AzWvdHostPool @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Host Pool updated successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to update the Azure Virtual Desktop Host Pool: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
