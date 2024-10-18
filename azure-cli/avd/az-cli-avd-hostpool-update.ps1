<#
.SYNOPSIS
    Update an Azure Virtual Desktop Host Pool with the Azure CLI.

.DESCRIPTION
    This script updates an Azure Virtual Desktop Host Pool with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization hostpool update --name $AzHostPoolName --resource-group $AzResourceGroup

.PARAMETER Add
    Add an object to a list of objects by specifying a path and key value pairs.

.PARAMETER CustomRdpProperty
    Custom RDP property.

.PARAMETER Description
    Description of the Azure Virtual Desktop Host Pool.

.PARAMETER ForceString
    Replace a string value with another string value.

.PARAMETER FriendlyName
    Friendly name of the Azure Virtual Desktop Host Pool.

.PARAMETER IDs
    One or more resource IDs (space-delimited).

.PARAMETER LoadBalancerType
    Load balancer type for the Azure Virtual Desktop Host Pool.

.PARAMETER MaxSessionLimit
    Maximum session limit for the Azure Virtual Desktop Host Pool.

.PARAMETER Name
    Name of the Azure Virtual Desktop Host Pool.

.PARAMETER PersonalDesktopAssignmentType
    Personal desktop assignment type for the Azure Virtual Desktop Host Pool.

.PARAMETER PreferredAppGroupType
    Preferred application group type for the Azure Virtual Desktop Host Pool.

.PARAMETER RegistrationInfo
    Registration information for the Azure Virtual Desktop Host Pool.

.PARAMETER Remove
    Remove a property or an element from a list.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group.

.PARAMETER Ring
    Ring for the Azure Virtual Desktop Host Pool.

.PARAMETER Set
    Update an object by specifying a property path and value to set.

.PARAMETER SsoClientId
    SSO client ID for the Azure Virtual Desktop Host Pool.

.PARAMETER SsoClientSecretKeyVaultPath
    SSO client secret key vault path for the Azure Virtual Desktop Host Pool.

.PARAMETER SsoSecretType
    SSO secret type for the Azure Virtual Desktop Host Pool.

.PARAMETER SsoadfsAuthority
    SSO ADFS authority for the Azure Virtual Desktop Host Pool.

.PARAMETER StartVmOnConnect
    Start VM on connect for the Azure Virtual Desktop Host Pool.

.PARAMETER Tags
    Tags for the Azure Virtual Desktop Host Pool.

.PARAMETER ValidationEnvironment
    Validation environment for the Azure Virtual Desktop Host Pool.

.PARAMETER VmTemplate
    VM template for the Azure Virtual Desktop Host Pool.

.EXAMPLE
    .\az-cli-avd-hostpool-update.ps1 -HostPoolName "MyHostPool" -ResourceGroup "MyResourceGroup"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/hostpool?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Add,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CustomRdpProperty,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

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
    [string]$ForceString,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Ids,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'BreadthFirst',
        'DepthFirst',
        'Persistent'
    )]
    [string]$LoadBalancerType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$MaxSessionLimit,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Automatic',
        'Direct'
    )]
    [string]$PersonalDesktopAssignmentType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Desktop',
        'None',
        'RailApplications'
    )]
    [string]$PreferredAppGroupType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$RegistrationInfo,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Remove,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Ring,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Set,

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
    [string]$SsoadfsAuthority,

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
    '--add', $Add
    '--custom-rdp-property', $CustomRdpProperty
    '--description', $Description
    '--force-string', $ForceString
    '--friendly-name', $FriendlyName
    '--ids', $Ids
    '--load-balancer-type', $LoadBalancerType
    '--max-session-limit', $MaxSessionLimit
    '--name', $Name
    '--personal-desktop-assignment-type', $PersonalDesktopAssignmentType
    '--preferred-app-group-type', $PreferredAppGroupType
    '--registration-info', $RegistrationInfo
    '--remove', $Remove
    '--resource-group', $ResourceGroup
    '--ring', $Ring
    '--set', $Set
    '--sso-client-id', $SsoClientId
    '--sso-client-secret-key-vault-path', $SsoClientSecretKeyVaultPath
    '--sso-secret-type', $SsoSecretType
    '--ssoadfs-authority', $SsoadfsAuthority
    '--start-vm-on-connect', $StartVmOnConnect
    '--tags', $Tags
    '--validation-environment', $ValidationEnvironment
    '--vm-template', $VmTemplate

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Update the Azure Virtual Desktop Host Pool
    az desktopvirtualization hostpool update @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Host Pool updated successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to update the Azure Virtual Desktop Host Pool: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
