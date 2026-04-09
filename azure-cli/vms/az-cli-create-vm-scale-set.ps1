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
    https://learn.microsoft.com/en-us/cli/azure/vmss

.COMPONENT
    Azure CLI Virtual Machines
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = 'myResourceGroup',

    [Parameter(Mandatory = $false, HelpMessage = "The name of the Azure VM Scale Set")]
    [ValidateNotNullOrEmpty()]
    [string]$AzScaleSetName = 'myScaleSet',

    [Parameter(Mandatory = $false, HelpMessage = "The orchestration mode of the Scale Set")]
    [ValidateSet("Flexible", "Uniform")]
    [string]$AzOrchestrationMode = 'Flexible',

    [Parameter(Mandatory = $false, HelpMessage = "The SKU image for the Scale Set")]
    [ValidateNotNullOrEmpty()]
    [string]$AzSkuImage = 'UbuntuLTS',

    [Parameter(Mandatory = $false, HelpMessage = "The instance count for the Scale Set")]
    [ValidateNotNullOrEmpty()]
    [int]$AzScaleSetInstanceCount = 2,

    [Parameter(Mandatory = $false, HelpMessage = "The admin username for the Scale Set VMs")]
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
    Write-Host "✅ Azure Virtual Machine Scale Set created successfully." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
