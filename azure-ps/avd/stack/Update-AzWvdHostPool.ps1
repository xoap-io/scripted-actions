<#
.SYNOPSIS
    Updates an Azure Virtual Desktop Host Pool.

.DESCRIPTION
    This script updates the properties of an Azure Virtual Desktop Host Pool.
    Uses the Update-AzWvdHostPool cmdlet from the Az.DesktopVirtualization module.

.PARAMETER Name
    The name of the host pool.

.PARAMETER ResourceGroup
    The name of the resource group.

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

.PARAMETER Tags
    A hashtable of tags to assign to the host pool.

.PARAMETER VMTemplate
    The VM template.

.PARAMETER ValidationEnvironment
    Specifies whether this is a validation environment.

.EXAMPLE
    PS C:\> .\Update-AzWvdHostPool.ps1 -Name "MyHostPool" -ResourceGroup "MyResourceGroup" -Description "Updated Description"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/update-azwvdhostpool?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the host pool to update.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[string]$AgentUpdateMaintenanceWindow,

    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[string]$AgentUpdateMaintenanceWindowTimeZone,

    [Parameter(Mandatory=$false, HelpMessage = "The type of agent update (Default or Scheduled).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Default",
        "Scheduled"
    )]
    [string]$AgentUpdateType,

    [Parameter(Mandatory=$false, HelpMessage = "Specifies whether to use the session host local time for updates.")]
    [ValidateNotNullOrEmpty()]
    [switch]$AgentUpdateUseSessionHostLocalTime,

    [Parameter(Mandatory=$false, HelpMessage = "Custom RDP properties for the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$CustomRdpProperty,

    [Parameter(Mandatory=$false, HelpMessage = "The description of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "The friendly display name of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false, HelpMessage = "The load balancer type for the host pool.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "BreadthFirst",
        "DepthFirst",
        'Persistent'
    )]
    [string]$LoadBalancerType,

    [Parameter(Mandatory=$false, HelpMessage = "The maximum number of sessions per session host.")]
    [ValidateNotNullOrEmpty()]
    [int]$MaxSessionLimit,

    [Parameter(Mandatory=$false, HelpMessage = "The personal desktop assignment type.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Automatic",
        "Direct"
    )]
    [string]$PersonalDesktopAssignmentType,

    [Parameter(Mandatory=$false, HelpMessage = "The preferred application group type.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Desktop",
        "None",
        'RailApplications'
    )]
    [string]$PreferredAppGroupType,

    [Parameter(Mandatory=$false, HelpMessage = "The public network access setting for the host pool.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Disabled",
        "Enabled",
        "EnabledForClientsOnly",
        'EnabledForSessionHostOnly'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false, HelpMessage = "The expiration time for registration info.")]
    [ValidateNotNullOrEmpty()]
    [DateTime]$RegistrationInfoExpirationTime,

    [Parameter(Mandatory=$false, HelpMessage = "The registration token operation (Delete, None, or Update).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Delete",
        "None",
        "Update"
    )]
    [String]$RegistrationInfoRegistrationTokenOperation,

    [Parameter(Mandatory=$false, HelpMessage = "The ring number for the host pool.")]
    [ValidateNotNullOrEmpty()]
    [int]$Ring,

    [Parameter(Mandatory=$false, HelpMessage = "The client ID for SSO.")]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientId,

    [Parameter(Mandatory=$false, HelpMessage = "The key vault path for the SSO client secret.")]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientSecretKeyVaultPath,

    [Parameter(Mandatory=$false, HelpMessage = "The type of SSO secret.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        "Certificate",
        "CertificateInKeyVault",
        "SharedKey",
        "SharedKeyInKeyVault"
    )]
    [string]$SsoSecretType,

    [Parameter(Mandatory=$false, HelpMessage = "The ADFS authority for SSO.")]
    [ValidateNotNullOrEmpty()]
    [string]$SsoadfsAuthority,

    [Parameter(Mandatory=$false, HelpMessage = "Specifies whether to start the VM on connect.")]
    [ValidateNotNullOrEmpty()]
    [switch]$StartVMOnConnect,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to assign to the host pool.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false, HelpMessage = "The VM template for the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$VMTemplate,

    [Parameter(Mandatory=$false, HelpMessage = "Specifies whether this is a validation environment.")]
    [ValidateNotNullOrEmpty()]
    [switch]$ValidationEnvironment
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroup
}

if ($AgentUpdateMaintenanceWindow) {
    $parameters['AgentUpdateMaintenanceWindow'] = $AgentUpdateMaintenanceWindow
}

if ($AgentUpdateMaintenanceWindowTimeZone) {
    $parameters['AgentUpdateMaintenanceWindowTimeZone'] = $AgentUpdateMaintenanceWindowTimeZone
}

if ($AgentUpdateType) {
    $parameters['AgentUpdateType'] = $AgentUpdateType
}

if ($AgentUpdateUseSessionHostLocalTime) {
    $parameters['AgentUpdateUseSessionHostLocalTime'] = $AgentUpdateUseSessionHostLocalTime
}

if ($CustomRdpProperty) {
    $parameters['CustomRdpProperty'] = $CustomRdpProperty
}

if ($Description) {
    $parameters['Description'] = $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'] = $FriendlyName
}

if ($LoadBalancerType) {
    $parameters['LoadBalancerType'] = $LoadBalancerType
}

if ($MaxSessionLimit) {
    $parameters['MaxSessionLimit'] = $MaxSessionLimit
}

if ($PersonalDesktopAssignmentType) {
    $parameters['PersonalDesktopAssignmentType'] = $PersonalDesktopAssignmentType
}

if ($PreferredAppGroupType) {
    $parameters['PreferredAppGroupType'] = $PreferredAppGroupType
}

if ($PublicNetworkAccess) {
    $parameters['PublicNetworkAccess'] = $PublicNetworkAccess
}

if ($RegistrationInfoExpirationTime) {
    $parameters['RegistrationInfoExpirationTime'] = $RegistrationInfoExpirationTime
}

if ($RegistrationInfoRegistrationTokenOperation) {
    $parameters['RegistrationInfoRegistrationTokenOperation'] = $RegistrationInfoRegistrationTokenOperation
}

if ($Ring) {
    $parameters['Ring'] = $Ring
}

if ($SsoClientId) {
    $parameters['SsoClientId'] = $SsoClientId
}

if ($SsoClientSecretKeyVaultPath) {
    $parameters['SsoClientSecretKeyVaultPath'] = $SsoClientSecretKeyVaultPath
}

if ($SsoSecretType) {
    $parameters['SsoSecretType'] = $SsoSecretType
}

if ($SsoadfsAuthority) {
    $parameters['SsoadfsAuthority'] = $SsoadfsAuthority
}

if ($StartVMOnConnect) {
    $parameters['StartVMOnConnect'] = $StartVMOnConnect
}

if ($Tags) {
    $parameters['Tag'] = $Tags
}

if ($VMTemplate) {
    $parameters['VMTemplate'] = $VMTemplate
}

if ($ValidationEnvironment) {
    $parameters['ValidationEnvironment'] = $ValidationEnvironment
}

try {
    # Update the Azure Virtual Desktop Host Pool and capture the result
    $result = Update-AzWvdHostPool @parameters

    # Output the result
    Write-Host "✅ Azure Virtual Desktop Host Pool updated successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
