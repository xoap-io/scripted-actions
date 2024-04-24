<#
.SYNOPSIS
    Create a new Azure VM Scale Set with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM Scale Set with the Azure PowerShell.
    The script uses the following Azure PowerShell command:
    New-AzVmss `
        -ResourceGroup $AzResourceGroupName `
        -Name $AzScaleSetName `
        -OrchestrationMode $AzOrchestrationMode `
        -Location $AzLocation `
        -InstanceCount $AzInstanceCount `
        -ImageName $AzImageName

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
    Azure PowerShell

.LINK
    https://github.com/xoap-io/scripted-actions

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

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzScaleSetName = "myScaleSet",
    [Parameter(Mandatory)]
    [ValidateSet('Uniform', 'Flexible')]
    [string]$AzOrchestrationMode,
    [Parameter(Mandatory)]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral',
        'asia', 'asiapacific', 'australia', 'brazil',
        'canada', 'europe', 'france', 'germany',
        'global', 'india', 'japan', 'korea',
        'norway', 'singapore', 'southafrica', 'sweden',
        'switzerland', 'unitedstates', 'northcentralus', 'westus',
        'japanwest', 'centraluseuap', 'eastus2euap', 'westcentralus',
        'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast',
        'koreasouth', 'southindia', 'westindia', 'canadaeast',
        'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest',
        'ukwest', 'uaecentral', 'brazilsoutheast'
    )]
    [string]$AzLocation,
    [Parameter(Mandatory)]
    [int]$AzInstanceCount = 2,
    [Parameter(Mandatory)]
<<<<<<< HEAD
    [string]$AzImageName = "myImageName"
=======
    [ValidateSet(
        'Win2022AzureEdition', 'Win2022AzureEditionCore', 'Win2019Datacenter', 'Win2016Datacenter', 
        'Win2012R2Datacenter', 'Win2012Datacenter', 'UbuntuLTS', 'Ubuntu2204', 
        'CentOS85Gen2', 'Debian11', 'OpenSuseLeap154Gen2', 'RHELRaw8LVMGen2', 
        'SuseSles15SP3', 'FlatcarLinuxFreeGen2'
    )]
    [string]$AzImageName
>>>>>>> d27ed172490c2a99af476a122f8fcfd7a8ae8575

)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

New-AzVmss `
    -ResourceGroup $AzResourceGroupName `
    -Name $AzScaleSetName `
    -OrchestrationMode $AzOrchestrationMode `
    -Location $AzResourceGroupName `
    -InstanceCount $AzInstanceCount `
    -ImageName $AzImageName `
