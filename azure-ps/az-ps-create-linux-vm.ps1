<#
.SYNOPSIS
    Create a new Linux Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Linux Azure VM with the Azure PowerShell.
    The script uses the Azure PowerShell to create the specified Linux Azure VM.
    The script uses the following Azure PowerShell command:
    New-AzVM -ResourceGroupName $AzResourceGroupName -Name $AzVmName -Location $AzLocation -Image $AzImageName -PublicIpAddressName $AzPublicIpAddressName -OpenPorts $AzOpenPorts -Size $AzVmSize
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

.PARAMETER AzVmName
    Defines the name of the Azure VM.

.PARAMETER AzLocation
    Defines the location of the Azure VM.

.PARAMETER AzImageName
    Defines the name of the Azure VM image.

.PARAMETER AzPublicIpAddressName
    Defines the name of the Azure VM public IP address.

.PARAMETER AzOpenPorts
    Defines the open ports of the Azure VM.

.PARAMETER AzVmSize
    Defines the size of the Azure VM.

.PARAMETER AzSshKeyName
    Defines the name of the SSH key.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = 'myResourceGroup',
    [Parameter(Mandatory)]
    [string]$AzVmName = 'myVmName',
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
    [string]$AzImageName = 'myImageName',
    [Parameter(Mandatory)]
    [string]$AzPublicIpAddressName = 'myPublicIpAddressName',
    [Parameter(Mandatory)]
    [int]$AZOpenPorts = 22,
    [Parameter(Mandatory)]
    [string]$AzVmSize = 'Standard_B1s',
    [Parameter(Mandatory)]
    [string]$AzSshKeyName

)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

New-AzVm `
    -ResourceGroupName $AzResourceGroupName `
    -Name $AzVmName `
    -Location $AzLocation `
    -image $AzImageName `
    -size $AzVmSize `
    -PublicIpAddressName $AzVmPublicIpAddressName `
    -OpenPorts $AZOpenPorts `
    -GenerateSshKey `
    -SshKeyName $AzSshKeyName
