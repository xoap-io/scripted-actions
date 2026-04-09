<#
.SYNOPSIS
    Delete an Azure Image Builder Windows VM.

.DESCRIPTION
    This script deletes an Azure Image Builder Windows VM.
    The script uses the Azure CLI to delete the specified Azure Image Builder Windows VM.
    The script uses the following Azure CLI commands:
    az resource delete --resource-group $AzResourceGroup --resource-type Microsoft.VirtualMachineImages/imageTemplates --name $AzImageBuildName
    az role assignment delete --assignee $AzAssignee --role $AzRoleDefinitionName --scope /subscriptions/$AzSubscriptionID/resourceGroups/$AzResourceGroup
    az role definition delete --name $AzRoleDefinitionName
    az identity delete --ids $AzResourceId
    az group delete --resource-group $AzResourceGroup

.PARAMETER AzResourceGroup
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

.EXAMPLE
    .\az-cli-delete-image-builder-windows.ps1 -AzResourceGroup "MyResourceGroup" -AzImageBuildName "MyImageBuild" -AzAssignee "MyAssignee" -AzRoleDefinitionName "MyRoleDefinition" -AzSubscriptionID "00000000-0000-0000-0000-000000000000" -AzResourceId "00000000-0000-0000-0000-000000000000"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "MyResourceGroup",

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Image Builder")]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageBuildName = "MyImageBuild",

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Role Assignee")]
    [ValidateNotNullOrEmpty()]
    [string]$AzAssignee = "MyAssignee",

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Role Definition")]
    [ValidateNotNullOrEmpty()]
    [string]$AzRoleDefinitionName = "MyRoleDefinition",

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the Azure Subscription")]
    [ValidateNotNullOrEmpty()]
    [string]$AzSubscriptionID = "00000000-0000-0000-0000-000000000000",

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the Azure Resource")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceId = "00000000-0000-0000-0000-000000000000"
)

# Splatting parameters for better readability
$parameters = @{
    resource_group        = $AzResourceGroup
    resource_type         = "Microsoft.VirtualMachineImages/imageTemplates"
    name                  = $AzImageBuildName
    assignee              = $AzAssignee
    role                  = $AzRoleDefinitionName
    scope                 = "/subscriptions/$AzSubscriptionID/resourceGroups/$AzResourceGroup"
    ids                   = $AzResourceId
    subscription          = $AzSubscriptionID
    debug                 = $AzDebug
    only_show_errors      = $AzOnlyShowErrors
    output                = $AzOutput
    query                 = $AzQuery
    verbose               = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Delete the Azure Image Builder
    az resource delete @parameters

    # Delete the role assignment
    az role assignment delete @parameters

    # Delete the role definition
    az role definition delete @parameters

    # Delete the managed identity
    az identity delete @parameters

    # Delete the resource group
    az group delete @parameters

    # Output the result
    Write-Host "✅ Azure Image Builder Windows VM deleted successfully." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
