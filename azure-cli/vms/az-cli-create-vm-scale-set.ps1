<#
.SYNOPSIS
    Create an Azure Virtual Machine Scale Set.

.DESCRIPTION
    This script creates an Azure Virtual Machine Scale Set.
    The script uses the Azure CLI to create the specified Azure Virtual Machine Scale Set.
    The script uses the following Azure CLI command:
    az vmss create --resource-group $AzResourceGroup --name $AzScaleSetName --orchestration-mode $AzOrchestrationMode --image $AzSkuImage --instance-count $AzScaleSetInstanceCount --admin-username $AzAdminUserName --generate-ssh-keys

.PARAMETER AzResourceGroup
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

.EXAMPLE
    .\az-cli-create-vm-scale-set.ps1 -AzResourceGroup "MyResourceGroup" -AzScaleSetName "MyScaleSet" -AzOrchestrationMode "Flexible" -AzSkuImage "UbuntuLTS" -AzScaleSetInstanceCount 2 -AzAdminUserName "azureuser"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vmss
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = 'myResourceGroup',

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
    [string]$AzAdminUserName = 'azureuser'
)

# Splatting parameters for better readability
$parameters = @{
    resource_group        = $AzResourceGroup
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