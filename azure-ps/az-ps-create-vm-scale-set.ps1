<#
.SYNOPSIS
    Create a new Azure VM Scale Set with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM Scale Set with the Azure PowerShell.
    The script uses the following Azure PowerShell command:
    New-AzVmss -ResourceGroup $AzResourceGroupName -Name $AzScaleSetName -OrchestrationMode $AzOrchestrationMode -Location $AzLocation -InstanceCount $AzInstanceCount -ImageName $AzImageName

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzScaleSetName
    Defines the name of the Azure Scale Set.

.PARAMETER AzOrchestrationMode
    Defines the orchestration mode of the Azure Scale Set.

.PARAMETER AzLocation
    Defines the location of the Azure Scale Set.

.PARAMETER AzInstanceCount
    Defines the instance count of the Azure Scale Set.

.PARAMETER AzImageName
    Defines the name of the Azure Scale Set image.

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
    .\az-ps-create-vm-scale-set.ps1 -AzResourceGroupName "myResourceGroup" -AzScaleSetName "myScaleSet" -AzOrchestrationMode "Uniform" -AzLocation "westus" -AzInstanceCount 2 -AzImageName "UbuntuLTS"

.NOTES
    Ensure that Azure PowerShell is installed and authenticated before running the script.
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure PowerShell

.LINK
    https://learn.microsoft.com/en-us/powershell/azure/new-azureps
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzScaleSetName,

    [Parameter(Mandatory=$true)]
    [ValidateSet('Uniform', 'Flexible')]
    [string]$AzOrchestrationMode,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzLocation,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int]$AzInstanceCount,

    [Parameter(Mandatory=$true)]
    [ValidateSet(
        'Win2022AzureEdition', 'Win2022AzureEditionCore', 'Win2019Datacenter', 'Win2016Datacenter',
        'Win2012R2Datacenter', 'Win2012Datacenter', 'UbuntuLTS', 'Ubuntu2204',
        'CentOS85Gen2', 'Debian11', 'OpenSuseLeap154Gen2', 'RHELRaw8LVMGen2',
        'SuseSles15SP3', 'FlatcarLinuxFreeGen2'
    )]
    [string]$AzImageName,

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
    ResourceGroupName    = $AzResourceGroupName
    Name                 = $AzScaleSetName
    OrchestrationMode    = $AzOrchestrationMode
    Location             = $AzLocation
    InstanceCount        = $AzInstanceCount
    ImageName            = $AzImageName
    Debug                = $AzDebug
    OnlyShowErrors       = $AzOnlyShowErrors
    Output               = $AzOutput
    Query                = $AzQuery
    Verbose              = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the VM Scale Set
    New-AzVmss @parameters

    # Output the result
    Write-Output "Azure VM Scale Set '$($AzScaleSetName)' created successfully in resource group '$($AzResourceGroupName)'."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to create Azure VM Scale Set: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}