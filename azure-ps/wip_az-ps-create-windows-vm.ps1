<# 
.SYNOPSIS 
    Create a new Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell. The script creates a new Azure Resource Group, a new Azure VM, and a new Azure Public IP Address.
    The script also retrieves the public IP address of the VM.

.NOTES 
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module. 
    The use of the scripts does not require XOAP, but it will make your life easier. 
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function, 
    the use and the consequences of the use of this freely available script. 
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG
 
.COMPONENT 


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

.PARAMETER AzVmUserName
    Defines the name of the Azure VM user.

.PARAMETER AzVmUserPassword
    Defines the password of the Azure VM user.

.PARAMETER AZOpenPorts
    Defines the open ports of the Azure VM.

.PARAMETER AzVmSize
    Defines the size of the Azure VM.

#>

param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AzVmName,
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
    [string]$AzImageName,
    [Parameter(Mandatory)]
    [string]$AzPublicIpAddressName,
    [Parameter(Mandatory)]
    [string]$AzVmUserName,
    [Parameter(Mandatory)]
    [securestring]$AzVmUserPassword,
    [Parameter(Mandatory)]
    [string]$AZOpenPorts = '3389',
    [Parameter(Mandatory)]
    [string]$AzVmSize
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

New-AzResourceGroup -Name $AzResourceGroupName -Location $AzLocation

$User = $AzVmUserName
$Password = ConvertTo-SecureString -String $AzVmUserPassword -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User, $Password


$vmParams = @{
    ResourceGroupName = $AzResourceGroupName
    Name = $AzVmName
    Location = $AzLocation
    ImageName = $AzImageName
    PublicIpAddressName = $AzPublicIpAddressName
    Credential = $Credential
    OpenPorts = $AZOpenPorts
    Size = $AzVmSize
  }

# Create the VM

New-AzVM @vmParams

# Get the public IP of the VM

$publicIp = Get-AzPublicIpAddress -Name $AzPublicIpAddressName -ResourceGroupName $AzResourceGroupName

$publicIp | Select-Object -Property Name, IpAddress, @{label='FQDN';expression={$_.DnsSettings.Fqdn}}
