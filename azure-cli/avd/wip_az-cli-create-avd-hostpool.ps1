<#
.SYNOPSIS
    Short description

.DESCRIPTION
    Long description

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT


.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('BreadthFirst', 'DepthFirst', 'Persistent')]
    [string]$AzLoadBalancerType
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az desktopvirtualization hostpool create --host-pool-type {BYODesktop, Personal, Pooled}
                                         --load-balancer-type {BreadthFirst, DepthFirst, Persistent}
                                         --name
                                         --preferred-app-group-type {Desktop, None, RailApplications}
                                         --resource-group
                                         [--custom-rdp-property]
                                         [--description]
                                         [--friendly-name]
                                         [--location]
                                         [--max-session-limit]
                                         [--personal-desktop-assignment-type {Automatic, Direct}]
                                         [--registration-info]
                                         [--ring]
                                         [--sso-client-id]
                                         [--sso-client-secret-key-vault-path]
                                         [--sso-secret-type {Certificate, CertificateInKeyVault, SharedKey, SharedKeyInKeyVault}]
                                         [--ssoadfs-authority]
                                         [--start-vm-on-connect {0, 1, f, false, n, no, t, true, y, yes}]
                                         [--tags]
                                         [--validation-environment {0, 1, f, false, n, no, t, true, y, yes}]
                                         [--vm-template]


az desktopvirtualization hostpool create `
    --resource-group $AzResourceGroupName `
    --name $AzHostPoolName `
    --friendly-name $AzHostPoolFriendlyName `
    --host-pool-type Pooled `
    --load-balancer-type BreadthFirst `
    --max-session-limit 999999 `
    --personal-desktop-assignment-type Automatic `
    --preferred-app-group-type Desktop `
    --registration-info expiration-time="yyyy-mm-ddT08:38:08.189Z" registration-token-operation=Update `
    --sso-client-id client `
    --sso-client-secret-key-vault-path https://keyvault/secret `
    --sso-secret-type SharedKey `
    --start-vm-on-connect false
