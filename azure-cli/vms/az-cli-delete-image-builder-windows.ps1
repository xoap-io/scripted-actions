<#
.SYNOPSIS
    Delete an Azure Image Builder Windows VM.

.DESCRIPTION
    This script deletes an Azure Image Builder Windows VM.
    The script uses the Azure CLI to delete the specified Azure Image Builder Windows VM.
    The script uses the following Azure CLI commands:
    az resource delete `
        --resource-group $AzResourceGroupName `
        --resource-type Microsoft.VirtualMachineImages/imageTemplates `
        --name $AzImageBuildName

    az role assignment delete `
        --assignee $AzAssignee `
        --role $AzRoleDefinitionName `
        --scope /subscriptions/$AzSubscriptionID/resourceGroups/$AzResourceGroupName

    az role definition delete `
        --name $AzRoleDefinitionName

    az identity delete `
        --ids $AzResourceId

    az group delete `
        --resource-group $AzResourceGroupName

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

.PARAMETER AzImageBuildName
    Defines the name of the Azure Image Builder.

.PARAMETER AzAssignee
    Defines the name of the Azure Role Assignee.

.PARAMETER AzRoleDefinitionName
    Defines the name of the Azure Role Definition.

.PARAMETER AzSubscriptionID
    Defines the ID of the Azure Subscription.

.PARAMETER AzResourceId
    Defines the ID of the Azure Resource.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "MyResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzImageBuildName = "MyImageBuild",
    [Parameter(Mandatory)]
    [string]$AzAssignee = "MyAssignee",
    [Parameter(Mandatory)]
    [string]$AzRoleDefinitionName = "MyRoleDefinition",
    [Parameter(Mandatory)]
    [string]$AzSubscriptionID = "00000000-0000-0000-0000-000000000000",
    [Parameter(Mandatory)]
    [string]$AzResourceId = "00000000-0000-0000-0000-000000000000"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

az resource delete `
    --resource-group $AzResourceGroupName `
    --resource-type Microsoft.VirtualMachineImages/imageTemplates `
    --name $AzImageBuildName

az role assignment delete `
    --assignee $AzAssignee `
    --role $AzRoleDefinitionName `
    --scope /subscriptions/$AzSubscriptionID/resourceGroups/$AzResourceGroupName

az role definition delete `
    --name $AzRoleDefinitionName

az identity delete `
    --ids $AzResourceId

az group delete `
    --resource-group $AzResourceGroupName
