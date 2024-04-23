<#
.SYNOPSIS
    This script creates an Azure Virtual Desktop Accelerator baseline deployment with Azure Bicep.

.DESCRIPTION
    This script creates an Azure Virtual Desktop Accelerator baseline deployment with Azure Bicep.
    The script uses the following Azure CLI command:
    az deployment create --template-file $AzBicepFile --parameters $AzBicepParametersFile --parameters avdWorkloadSubsId=$AzSubscriptionId --parameters deploymentPrefix=$AzDeploymentPrefix --parameters avdVmLocalUserName=$AzVmLocalUserName --parameters avdVmLocalUserPassword=$AzLocalUserPassword --parameters avdIdentityServiceProvider=$AzIdentityServiceProvider --parameters avdIdentityDomainName=$AzIdentityDomainName --parameters avdDomainJoinUserName=$AzDomainJoinUserName --parameters avdDomainJoinUserPassword=$AzDomainJoinUserPassword --parameters existingHubVnetResourceId=$AzHubVnetResourceId --parameters customDnsIps=$AzCustomDnsIps --parameters avdEnterpriseAppObjectId=$AzEnterpriseAppObjectId --parameters avdVnetPrivateDnsZone=true --parameters avdVnetPrivateDnsZoneFilesId=$AzPrivateDnsZoneFilesId --parameters avdVnetPrivateDnsZoneKeyvaultId=$AzPrivateDnsZoneKeyvaultId --avdDeployMonitoring=true --deployAlaWorkspace=true --location $AzLocation

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

.LINK
    https://github.com/Azure/avdaccelerator/tree/main/workload/bicep

.PARAMETER AzBicepFile
    Defines the path to the Azure Bicep file.

.PARAMETER AzBicepParametersFile
    Defines the path to the Azure Bicep parameters file.

.PARAMETER AzSubscriptionId
    AVD workload subscription ID, multiple subscriptions scenario. (Default: "")

.PARAMETER AzDeploymentPrefix
    The name of the resource group to deploy. (Default: AVD1)

.PARAMETER AzVmLocalUserName
    AVD session host local username.

.PARAMETER AzLocalUserPassword
    AVD session host local password.

.PARAMETER AzIdentityServiceProvider
    The service providing domain services for Azure Virtual Desktop. (Default: ADDS)

.PARAMETER AzIdentityDomainName
    FQDN of on-premises AD domain, used for FSLogix storage configuration and NTFS setup. (Default: "")

.PARAMETER AzDomainJoinUserName
    AVD session host domain join user principal name. (Default: none)

.PARAMETER AzDomainJoinUserPassword
    AVD session host domain join password. (Default: none)

.PARAMETER AzHubVnetResourceId
    Existing hub virtual network for perring. (Default: "")

.PARAMETER AzCustomDnsIps
    Custom DNS IPs for the AVD session host. (Default: "")

.PARAMETER AzEnterpriseAppObjectId
    The object ID of the enterprise application. (Default: "")

.PARAMETER AzPrivateDnsZoneFilesId
    Create new Azure private DNS zones for private endpoints. (Default: true)

.PARAMETER AzPrivateDnsZoneKeyvaultId
    Use existing Azure private DNS zone for key vault privatelink.vaultcore.azure.net or privatelink.vaultcore.usgovcloudapi.net. (Default: "")

.PARAMETER AzLocation
        Defines the location of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzBicepFile,
    [Parameter(Mandatory)]
    [string]$AzBicepParametersFile,
    [Parameter(Mandatory)]
    [string]$AzSubscriptionId,
    [Parameter(Mandatory)]
    [string]$AzDeploymentPrefix,
    [Parameter(Mandatory)]
    [string]$AzVmLocalUserName,
    [Parameter(Mandatory)]
    [securestring]$AzLocalUserPassword,
    [Parameter(Mandatory)]
    [string]$AzIdentityServiceProvider,
    [Parameter(Mandatory)]
    [string]$AzIdentityDomainName,
    [Parameter(Mandatory)]
    [string]$AzDomainJoinUserName,
    [Parameter(Mandatory)]
    [securestring]$AzDomainJoinUserPassword,
    [Parameter(Mandatory)]
    [string]$AzHubVnetResourceId,
    [Parameter(Mandatory)]
    [string]$AzCustomDnsIps,
    [Parameter(Mandatory)]
    [string]$AzEnterpriseAppObjectId,
    [Parameter(Mandatory)]
    [string]$AzPrivateDnsZoneFilesId,
    [Parameter(Mandatory)]
    [string]$AzPrivateDnsZoneKeyvaultId,
    [Parameter(Mandatory)]
    [string]$AzLocation
    )

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

az deployment create `
  --template-file $AzBicepFile `
  --parameters $AzBicepParametersFile `
  --parameters avdWorkloadSubsId=$AzSubscriptionId `
  --parameters deploymentPrefix=$AzDeploymentPrefix `
  --parameters avdVmLocalUserName=$AzVmLocalUserName `
  --parameters avdVmLocalUserPassword=$AzLocalUserPassword `
  --parameters avdIdentityServiceProvider=$AzIdentityServiceProvider `
  --parameters avdIdentityDomainName=$AzIdentityDomainName `
  --parameters avdDomainJoinUserName=$AzDomainJoinUserName ` `
  --parameters avdDomainJoinUserPassword=$AzDomainJoinUserPassword `
  --parameters existingHubVnetResourceId=$AzHubVnetResourceId  `
  --parameters customDnsIps=$AzCustomDnsIps `
  --parameters avdEnterpriseAppObjectId=$AzEnterpriseAppObjectId `
  --parameters avdVnetPrivateDnsZone=true `
  --parameters avdVnetPrivateDnsZoneFilesId=$AzPrivateDnsZoneFilesId `
  --parameters avdVnetPrivateDnsZoneKeyvaultId=$AzPrivateDnsZoneKeyvaultId `
  --avdDeployMonitoring=true `
  --deployAlaWorkspace=true `
  --location $AzLocation
