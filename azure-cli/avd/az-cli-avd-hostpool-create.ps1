<#
.SYNOPSIS
    Create an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Desktop Host Pool with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization hostpool create --host-pool-type $AzHostPoolType --load-balancer-type $AzLoadBalancerType --name $AzHostPoolName --preferred-app-group-type $AzPreferredAppGroupType --resource-group $AzResourceGroup --custom-rdp-property $AzCustomRdpProperty --description $AzDescription --friendly-name $AzFriendlyName --location $AzLocation --max-session-limit $AzMaxSessionLimit --personal-desktop-assignment-type $AzPersonalDesktopAssignmentType --registration-info $AzRegistrationInfo --sso-client-id $AzSsoClientId --sso-client-secret-key-vault-path $AzSsoClientSecretKeyVaultPath --sso-secret-type $AzSsoSecretType --ssoadfs-authority $AzSsoAdfsAuthority --start-vm-on-connect $AzStartVmOnConnect --tags $AzTags --validation-environment $AzValidationEnvironment --vm-template $AzVmTemplate

.PARAMETER HostPoolType
    Defines the type of the Azure Virtual Desktop Host Pool.

.PARAMETER LoadBalancerType
    Defines the type of the Azure Virtual Desktop Load Balancer.

.PARAMETER HostPoolName
    Defines the name of the Azure Virtual Desktop Host Pool.

.PARAMETER PreferredAppGroupType
    Defines the preferred application group type.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER CustomRdpProperty
    Defines the custom RDP property.

.PARAMETER Description
    Defines the description of the Azure Virtual Desktop Host Pool.

.PARAMETER FriendlyName
    Defines the friendly name of the Azure Virtual Desktop Host Pool.

.PARAMETER Location
    Defines the location of the Azure Virtual Desktop Host Pool.

.PARAMETER MaxSessionLimit
    Defines the maximum session limit.

.PARAMETER PersonalDesktopAssignmentType
    Defines the personal desktop assignment type.

.PARAMETER RegistrationInfo
    Defines the registration information.

.PARAMETER SsoClientId
    Defines the SSO client ID.

.PARAMETER SsoClientSecretKeyVaultPath
    Defines the SSO client secret key vault path.

.PARAMETER SsoSecretType
    Defines the SSO secret type.

.PARAMETER SsoAdfsAuthority
    Defines the SSO ADFS authority.

.PARAMETER StartVmOnConnect
    Defines whether to start the VM on connect.

.PARAMETER Tags
    Defines the tags for the Azure Virtual Desktop Host Pool.

.PARAMETER ValidationEnvironment
    Defines the validation environment.

.PARAMETER VmTemplate
    Defines the VM template.

.EXAMPLE
    .\az-cli-avd-hostpool-create.ps1 -AzHostPoolName "MyHostPool" -AzResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'BYODesktops',
        'Pooled',
        'Personal'
    )]
    [string]$HostPoolType,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'BreadthFirst',
        'DepthFirst',
        'Persistent'
    )]
    [string]$LoadBalancerType,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Desktop',
        'None',
        'RailApplications'
    )]
    [string]$PreferredAppGroupType,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

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
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$MaxSessionLimit,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Automatic',
        'Direct'
    )]
    [string]$PersonalDesktopAssignmentType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationInfo,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoClientSecretKeyVaultPath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Certificate',
        'CertificateInKeyVault',
        'SharedKey',
        'SharedKeyInKeyVault'
    )]
    [string]$SsoSecretType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SsoAdfsAuthority,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$StartVmOnConnect,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        '0',
        '1',
        'f',
        'false',
        'n',
        'no',
        't',
        'true',
        'y',
        'yes'
    )]
    [string]$ValidationEnvironment,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VmTemplate
)

# Splatting parameters for better readability
$parameters = `
    '--host-pool-type', $HostPoolType
    '--load-balancer-type', $LoadBalancerType
    '--name', $HostPoolName
    '--preferred-app-group-type', $PreferredAppGroupType
    '--resource-group', $ResourceGroup

if ($CustomRdpProperty) {
    $parameters += '--custom-rdp-property', $CustomRdpProperty
}

if ($Description) {
    $parameters += '--description', $Description
}

if ($FriendlyName) {
    $parameters += '--friendly-name', $FriendlyName
}

if ($Location) {
    $parameters += '--location', $Location
}

if ($MaxSessionLimit) {
    $parameters += '--max-session-limit', $MaxSessionLimit
}

if ($PersonalDesktopAssignmentType) {
    $parameters += '--personal-desktop-assignment-type', $PersonalDesktopAssignmentType
}

if ($RegistrationInfo) {
    $parameters += '--registration-info', $RegistrationInfo
}

if ($SsoClientId) {
    $parameters += '--sso-client-id', $SsoClientId
}

if ($SsoClientSecretKeyVaultPath) {
    $parameters += '--sso-client-secret-key-vault-path', $SsoClientSecretKeyVaultPath
}

if ($SsoSecretType) {
    $parameters += '--sso-secret-type', $SsoSecretType
}

if ($SsoAdfsAuthority) {
    $parameters += '--ssoadfs-authority', $SsoAdfsAuthority
}

if ($StartVmOnConnect) {
    $parameters += '--start-vm-on-connect', $StartVmOnConnect
}

if ($Tags) {
    $parameters += '--tags', $Tags
}

if ($ValidationEnvironment) {
    $parameters += '--validation-environment', $ValidationEnvironment
}

if ($VmTemplate) {
    $parameters += '--vm-template', $VmTemplate
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the Azure Virtual Desktop Host Pool
    az desktopvirtualization hostpool create @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Host Pool created successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Virtual Desktop Host Pool: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
