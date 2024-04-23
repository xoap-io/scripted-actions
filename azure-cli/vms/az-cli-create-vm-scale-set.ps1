<#
.SYNOPSIS
    Create an Azure Virtual Machine Scale Set.

.DESCRIPTION
    This script creates an Azure Virtual Machine Scale Set.
    The script uses the Azure CLI to create the specified Azure Virtual Machine Scale Set.
    The script uses the following Azure CLI command:
    az vmss create `
      --resource-group $AzResourceGroupName `
      --name $AzScaleSetName `
      --orchestration-mode $AzOrchestrationMode `
      --image $AzSkuImage `
      --instance-count $AzScaleSetInstanceCount `
      --admin-username $AzAdminUserName `
      --generate-ssh-keys

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

.PARAMETER AzScaleSetName
    Defines the name of the Azure Scale Set.

.PARAMETER AzOrchestrationMode
    Defines the orchestration mode of the Azure Scale Set.

.PARAMETER AzSkuImage
    Defines the SKU image of the Azure Scale Set.

.PARAMETER AzScaleSetInstanceCount
    Defines the instance count of the Azure Scale Set.

.PARAMETER AzAdminUserName
    Defines the admin username of the Azure Scale Set.
    
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = 'myResourceGroup',
    [Parameter(Mandatory)]
    [string]$AzScaleSetName = 'myScaleSet',
    [Parameter(Mandatory)]
    [ValidateSet("Flexible", "Uniform")]
    [string]$AzOrchestrationMode = 'Flexible',
    [Parameter(Mandatory)]
    [string]$AzSkuImage = 'UbuntuLTS',
    [Parameter(Mandatory)]
    [string]$AzScaleSetInstanceCount = 2,
    [Parameter(Mandatory)]
    [string]$AzAdminUserName = 'azureuser'
    )

# Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

az vmss create `
  --resource-group $AzResourceGroupName `
  --name $AzScaleSetName `
  --orchestration-mode $AzOrchestrationMode `
  --image $AzSkuImage `
  --instance-count $AzScaleSetInstanceCount `
  --admin-username $AzAdminUserName `
  --generate-ssh-keys
