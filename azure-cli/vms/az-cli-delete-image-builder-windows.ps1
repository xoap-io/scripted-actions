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

.PARAMETER AzDebug
    Increase logging verbosity to show all debug logs.

.PARAMETER AzOnlyShowErrors
    Only show errors, suppressing warnings.

.PARAMETER AzOutput
    Output format.

.PARAMETER AzQuery
    JMESPath query string.

.PARAMETER AzVerbose
    Increase logging verbosity.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

.EXAMPLE
    .\az-cli-delete-image-builder-windows.ps1 -AzResourceGroup "MyResourceGroup" -AzImageBuildName "MyImageBuild" -AzAssignee "MyAssignee" -AzRoleDefinitionName "MyRoleDefinition" -AzSubscriptionID "00000000-0000-0000-0000-000000000000" -AzResourceId "00000000-0000-0000-0000-000000000000"

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "MyResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageBuildName = "MyImageBuild",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzAssignee = "MyAssignee",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzRoleDefinitionName = "MyRoleDefinition",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzSubscriptionID = "00000000-0000-0000-0000-000000000000",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceId = "00000000-0000-0000-0000-000000000000",

    [Parameter(Mandatory=$false)]
    [switch]$AzDebug,

    [Parameter(Mandatory=$false)]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory=$false)]
    [string]$AzOutput,

    [Parameter(Mandatory=$false)]
    [string]$AzQuery,

    [Parameter(Mandatory=$false)]
    [switch]$AzVerbose,


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
    Write-Output "Azure Image Builder Windows VM deleted successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to delete the Azure Image Builder Windows VM: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}