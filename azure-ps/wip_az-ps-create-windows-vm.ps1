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
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [string]$AzVmName = "myVm",
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
    [string]$AzImageName = "myImageName",
    [Parameter(Mandatory)]
    [string]$AzPublicIpAddressName = "myPublicIpAddressName",
    [Parameter(Mandatory)]
    [string]$AzVmUserName = "myVmUser",
    [Parameter(Mandatory)]
    [securestring]$AzVmUserPassword = "myVmPassword",
    [Parameter(Mandatory)]
    [int]$AZOpenPorts = '3389',
    [Parameter(Mandatory)]
    [ValidateSet('Standard_A0', 'Standard_A1', 'Standard_A2', 'Standard_A3', 'Standard_A4', 'Standard_A5', 'Standard_A6', 'Standard_A7', 'Standard_A8', 'Standard_A9', 'Standard_A10', 'Standard_A11', 'Standard_A1_v2', 'Standard_A2_v2', 'Standard_A4_v2', 'Standard_A8_v2', 'Standard_A2m_v2', 'Standard_A4m_v2', 'Standard_A8m_v2', 'Standard_B1s', 'Standard_B1ms', 'Standard_B2s', 'Standard_B2ms', 'Standard_B4ms', 'Standard_B8ms', 'Standard_B12ms', 'Standard_B16ms', 'Standard_B20ms', 'Standard_B24ms', 'Standard_B1ls', 'Standard_B1s', 'Standard_B2s', 'Standard_B4s', 'Standard_B8s', 'Standard_B12s', 'Standard_B16s', 'Standard_B20s', 'Standard_B24s', 'Standard_D1', 'Standard_D2', 'Standard_D3', 'Standard_D4', 'Standard_D11', 'Standard_D12', 'Standard_D13', 'Standard_D14', 'Standard_D1_v2', 'Standard_D2_v2', 'Standard_D3_v2', 'Standard_D4_v2', 'Standard_D5_v2', 'Standard_D11_v2', 'Standard_D12_v2', 'Standard_D13_v2', 'Standard_D14_v2', 'Standard_D15_v2', 'Standard_D2_v3', 'Standard_D4_v3', 'Standard_D8_v3', 'Standard_D16_v3', 'Standard_D32_v3', 'Standard_D48_v3', 'Standard_D64_v3', 'Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_D8s_v3', 'Standard_D16s_v3', 'Standard_D32s_v3', 'Standard_D48s_v3', 'Standard_D64s_v3', 'Standard_D2_v4', 'Standard_D4_v4', 'Standard_D8_v4', 'Standard_D16_v4', 'Standard_D32_v4', 'Standard_D48_v4', 'Standard_D64_v4', 'Standard_D2s_v4')]
    [string]$AzVmSize
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

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
