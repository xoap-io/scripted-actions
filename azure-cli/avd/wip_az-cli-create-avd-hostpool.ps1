<#
.SYNOPSIS
    This script creates an Azure Virtual Desktop Host Pool.

.DESCRIPTION
    This script creates an Azure Virtual Desktop Host Pool.
    The script uses the following Azure CLI command:
    az desktopvirtualization hostpool create --host-pool-type $AzHostPoolType --load-balancer-type $AzLoadBalancerType --name $AzHostPoolName --preferred-app-group-type $AzPreferredAppGroupType --resource-group $AzResourceGroupName --custom-rdp-property $AzCustomRdpProperty --description $AzDescription --friendly-name $AzFriendlyName --location $AzLocation --max-session-limit $AzMaxSessionLimit --personal-desktop-assignment-type $AzPersonalDesktopAssignmentType --registration-info $AzRegistrationInfo --sso-client-id $AzSsoClientId --sso-client-secret-key-vault-path $AzSsoClientSecretKeyVaultPath --sso-secret-type $AzSsoSecretType --ssoadfs-authority $AzSsoAdfsAuthority --start-vm-on-connect $AzStartVmOnConnect --tags $AzTags --validation-environment $AzValidationEnvironment --vm-template $AzVmTemplate

    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    
    It does not return any output.

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
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzHostPoolName
    Defines the name of the Azure Virtual Desktop Host Pool.

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzHostPoolFriendlyName

.PARAMETER AzHostPoolType
    Defines the type of the Azure Host Pool.

.PARAMETER AzPreferredAppGroupType
    Defines the preferred app group type.

.PARAMETER AzRegistrationInfo
    Defines the registration info.

.PARAMETER AzSsoClientId
    Defines the SSO client ID.

.PARAMETER AzSsoClientSecretKeyVaultPath
    Defines the SSO client secret key vault path.

.PARAMETER AzSsoSecretType
    Defines the SSO secret type.

.PARAMETER AzStartVmOnConnect
    Defines if the VM should start on connect.

.PARAMETER AzValidationEnvironment
    Defines the validation environment.

.PARAMETER AzVmTemplate
    Defines the VM template.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('BreadthFirst', 'DepthFirst', 'Persistent')]
    [string]$AzLoadBalancerType,
    [Parameter(Mandatory)]
    [string]$AzHostPoolName = 'myHostPoolName',
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = 'myResourceGroupName',
    [Parameter(Mandatory)]
    [string]$AzHostPoolFriendlyName = 'myFriendlyName',
    [Parameter(Mandatory)]
    [ValidateSet('BYODesktop', 'Personal', 'Pooled')]
    [string]$AzHostPoolType,
    [Parameter(Mandatory)]
    [ValidateSet('Desktop', 'None', 'RailApplications')]
    [string]$AzPreferredAppGroupType,
    [Parameter(Mandatory)]
    [string]$AzSsoClientId = 'myClientId',
    [Parameter(Mandatory)]
    [string]$AzSsoClientSecretKeyVaultPath = 'myKeyVaultPath',
    [Parameter(Mandatory)]
    [ValidateSet('Certificate', 'CertificateInKeyVault', 'SharedKey', 'SharedKeyInKeyVault')]
    [string]$AzSsoSecretType,
    [Parameter(Mandatory)]
    [ValidateSet('0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes')]
    [string]$AzStartVmOnConnect,
    [Parameter(Mandatory)]
    [ValidateSet('0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes')]
    [string]$AzValidationEnvironment,
    [Parameter(Mandatory)]
    [string]$AzVmTemplate = 'Windows-10-Enterprise-N-x64',
    [Parameter(Mandatory)]
    [string]$AzLocation = 'westeurope',
    [Parameter(Mandatory)]
    [string]$AzMaxSessionLimit = 999999,
    [Parameter(Mandatory)]
    [ValidateSet('Automatic', 'Direct')]
    [string]$AzPersonalDesktopAssignmentType = 'Automatic',
    [Parameter(Mandatory)]
    [string]$AzSsoAdfsAuthority = 'https://adfs.contoso.com/adfs',
    [Parameter(Mandatory = $false)]
    [string]$AzCustomRdpProperty = 'audiocapturemode:i:1;audiomode:i:0;authentication level:i:2;autoreconnection enabled:i:1;bitmapcachepersistenable:i:1;bitmapcachesize:i:1;compression:i:1;connection type:i:7;desktopheight:i:900;desktopwidth:i:1440;disable full window drag:i:1;disable menu anims:i:1;disable themes:i:0;disable wallpaper:i:0;displayconnectionbar:i:1;domain:s:contoso.com;enablecredsspsupport:i:1;full address:s:rdp.contoso.com;gatewayaccesstoken:s:;gatewaycredentialssource:i:0;gatewayhostname:s:;gatewayprofileusagemethod:i:0;gatewayusagemethod:i:0;keyboardhook:i:2;loadbalanceinfo:s:tsv://MS Terminal Services Plugin.1.Contoso;negotiate security layer:i:1;prompt for credentials:i:0;promptcredentialonce:i:0;redirectclipboard:i:1;remoteapplicationcmdline:s:;remoteapplicationexpandcmdline:s:1;remoteapplicationexpandworkingdir:s:1;remoteapplicationfile:s:;remoteapplicationguid:s:;remoteapplicationname:s:RemoteApp;remoteapplicationprogram:s:||RemoteApp;remoteapplicationprogrammode:i:1;remoteapplicationprogramse',
    [Parameter(Mandatory)]
    [string]$AzDescription = 'myDescription',
    [Parameter(Mandatory)]
    [string]$AzFriendlyName = 'myFriendlyName',
    [Parameter(Mandatory)]
    [string]$AzRegistrationInfo = 'expiration-time="yyyy-mm-ddT08:38:08.189Z" registration-token-operation=Update',
    [Parameter(Mandatory)]
    [string]$AzSsoClientId = 'client',
    [Parameter(Mandatory)]
    [ValidateSet('0', '1', 'f', 'false', 'n', 'no', 't', 'true', 'y', 'yes')]
    [string]$AzStartVmOnConnect = 'false',
    [Parameter(Mandatory)]
    [string]$AzTags = 'myTags'
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

az desktopvirtualization hostpool create --host-pool-type $AzHostPoolType `
    --load-balancer-type $AzLoadBalancerType `
    --name $AzHostPoolName `
    --preferred-app-group-type $AzPreferredAppGroupType `
    --resource-group $AzResourceGroupName `
    --custom-rdp-property $AzCustomRdpProperty `
    --description $AzDescription `
    --friendly-name $AzFriendlyName `
    --location $AzLocation `
    --max-session-limit $AzMaxSessionLimit `
    --personal-desktop-assignment-type $AzPersonalDesktopAssignmentType `
    --registration-info $AzRegistrationInfo `
    --sso-client-id $AzSsoClientId `
    --sso-client-secret-key-vault-path $AzSsoClientSecretKeyVaultPath `
    --sso-secret-type $AzSsoSecretType `
    --ssoadfs-authority $AzSsoAdfsAuthority `
    --start-vm-on-connect $AzStartVmOnConnect `
    --tags $AzTags `
    --validation-environment $AzValidationEnvironment `
    --vm-template $AzVmTemplate
