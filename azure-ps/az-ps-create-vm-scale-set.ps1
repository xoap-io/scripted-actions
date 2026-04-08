<#
.SYNOPSIS
    Create a new Azure VM Scale Set with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM Scale Set with the Azure PowerShell.
    The script uses the following Azure PowerShell command:
    New-AzVmss -ResourceGroupName $AzResourceGroup -Name $AzScaleSetName -OrchestrationMode $AzOrchestrationMode -Location $AzLocation -InstanceCount $AzInstanceCount -ImageName $AzImageName

.PARAMETER AzResourceGroup
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

.EXAMPLE
    .\az-ps-create-vm-scale-set.ps1 -AzResourceGroup "myResourceGroup" -AzScaleSetName "myScaleSet" -AzOrchestrationMode "Uniform" -AzLocation "westus" -AzInstanceCount 2 -AzImageName "UbuntuLTS"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az)

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azvmss

.COMPONENT
    Azure PowerShell Compute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Scale Set.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzScaleSetName,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the orchestration mode of the Azure Scale Set.")]
    [ValidateSet('Uniform', 'Flexible')]
    [string]$AzOrchestrationMode,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the location of the Azure Scale Set.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzLocation,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the instance count of the Azure Scale Set.")]
    [ValidateNotNullOrEmpty()]
    [int]$AzInstanceCount,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Scale Set image.")]
    [ValidateSet(
        'Win2022AzureEdition', 'Win2022AzureEditionCore', 'Win2019Datacenter', 'Win2016Datacenter',
        'Win2012R2Datacenter', 'Win2012Datacenter', 'UbuntuLTS', 'Ubuntu2204',
        'CentOS85Gen2', 'Debian11', 'OpenSuseLeap154Gen2', 'RHELRaw8LVMGen2',
        'SuseSles15SP3', 'FlatcarLinuxFreeGen2'
    )]
    [string]$AzImageName,

    [Parameter(Mandatory = $false, HelpMessage = "Increase logging verbosity to show all debug logs.")]
    [switch]$AzDebug,

    [Parameter(Mandatory = $false, HelpMessage = "Only show errors, suppressing warnings.")]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory = $false, HelpMessage = "Output format.")]
    [string]$AzOutput,

    [Parameter(Mandatory = $false, HelpMessage = "JMESPath query string.")]
    [string]$AzQuery,

    [Parameter(Mandatory = $false, HelpMessage = "Increase logging verbosity.")]
    [switch]$AzVerbose
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName = $AzResourceGroup
    Name              = $AzScaleSetName
    OrchestrationMode = $AzOrchestrationMode
    Location          = $AzLocation
    InstanceCount     = $AzInstanceCount
    ImageName         = $AzImageName
    Debug             = $AzDebug
    OnlyShowErrors    = $AzOnlyShowErrors
    Output            = $AzOutput
    Query             = $AzQuery
    Verbose           = $AzVerbose
}

try {
    # Create the VM Scale Set
    New-AzVmss @parameters

    # Output the result
    Write-Host "✅ Azure VM Scale Set '$($AzScaleSetName)' created successfully in resource group '$($AzResourceGroup)'." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
