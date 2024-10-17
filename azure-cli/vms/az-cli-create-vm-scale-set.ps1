<#
.SYNOPSIS
    Create an Azure Virtual Machine Scale Set.

.DESCRIPTION
    This script creates an Azure Virtual Machine Scale Set.
    The script uses the Azure CLI to create the specified Azure Virtual Machine Scale Set.
    The script uses the following Azure CLI command:
    az vmss create --resource-group $AzResourceGroupName --name $AzScaleSetName --orchestration-mode $AzOrchestrationMode --image $AzSkuImage --instance-count $AzScaleSetInstanceCount --admin-username $AzAdminUserName --generate-ssh-keys

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

.PARAMETER AzSubscription
    Name or ID of subscription.

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
    .\az-cli-create-vm-scale-set.ps1 -AzResourceGroupName "MyResourceGroup" -AzScaleSetName "MyScaleSet" -AzOrchestrationMode "Flexible" -AzSkuImage "UbuntuLTS" -AzScaleSetInstanceCount 2 -AzAdminUserName "azureuser"

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vmss
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroupName = 'myResourceGroup',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzScaleSetName = 'myScaleSet',

    [Parameter(Mandatory=$true)]
    [ValidateSet("Flexible", "Uniform")]
    [string]$AzOrchestrationMode = 'Flexible',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzSkuImage = 'UbuntuLTS',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int]$AzScaleSetInstanceCount = 2,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzAdminUserName = 'azureuser',

    [Parameter(Mandatory=$false)]
    [string]$AzSubscription,

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
    resource_group        = $AzResourceGroupName
    name                  = $AzScaleSetName
    orchestration_mode    = $AzOrchestrationMode
    image                 = $AzSkuImage
    instance_count        = $AzScaleSetInstanceCount
    admin_username        = $AzAdminUserName
    subscription          = $AzSubscription
    debug                 = $AzDebug
    only_show_errors      = $AzOnlyShowErrors
    output                = $AzOutput
    query                 = $AzQuery
    verbose               = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create an Azure Virtual Machine Scale Set
    az vmss create @parameters

    # Output the result
    Write-Output "Azure Virtual Machine Scale Set created successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to create the Azure Virtual Machine Scale Set: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}