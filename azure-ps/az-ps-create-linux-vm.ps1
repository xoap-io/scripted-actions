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
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

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
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzVmName,
    [Parameter(Mandatory)]
    [ValidateSet('eastus', 'eastus2', 'germany', 'northeurope', 'germanywestcentral')]
    [string]$AzLocation,
    [Parameter(Mandatory)]
    [string]$AzImageName,
    [Parameter(Mandatory)]
    [string]$AzPublicIpAddressName,
    [Parameter(Mandatory)]
    [Securestring]$AZOpenPorts,
    [Parameter(Mandatory)]
    [string]$AzVmSize,
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
