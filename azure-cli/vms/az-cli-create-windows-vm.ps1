<#

.SYNOPSIS
    Create a new Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell. The script creates a new Azure Resource Group, a new Azure VM, and a new Azure Public IP Address.
    The script also retrieves the public IP address of the VM.

.PARAMETER Name
    Defines the name of the Azure VM.

.PARAMETER UserName
    Defines the username for the Azure VM.

.PARAMETER Password
    Defines the password for the Azure VM.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Location
    Defines the location of the Azure VM.

.PARAMETER EdgeZone
    Defines the edge zone of the Azure VM.

.PARAMETER Zone
    Defines the zone of the Azure VM.

.PARAMETER PublicIpSku
    Defines the SKU of the public IP address.

.PARAMETER NetworkInterfaceDeleteOption
    Defines the network interface delete option.

.PARAMETER NetworkName
    Defines the name of the virtual network.

.PARAMETER AddressPrefix
    Defines the address prefix of the virtual network.

.PARAMETER SubnetName
    Defines the name of the subnet.

.PARAMETER SubnetAddressPrefix
    Defines the address prefix of the subnet.

.PARAMETER PublicIpAddressName
    Defines the name of the public IP address.

.PARAMETER DomainNameLabel
    Defines the domain name label.

.PARAMETER AllocationMethod
    Defines the allocation method.

.PARAMETER SecurityGroupName
    Defines the security group name.

.PARAMETER OpenPorts
    Defines the open ports.

.PARAMETER Image
    Defines the image to use for the VM.

.PARAMETER Size
    Defines the size of the VM.

.PARAMETER AvailabilitySetName
    Defines the availability set name.

.PARAMETER SystemAssignedIdentity
    Defines the system-assigned identity.

.PARAMETER UserAssignedIdentity
    Defines the user-assigned identity.

.PARAMETER OSDiskDeleteOption
    Defines the OS disk delete option.

.PARAMETER DataDiskSizeInGb
    Defines the data disk size in GB.

.PARAMETER DataDiskDeleteOption
    Defines the data disk delete option.

.PARAMETER EnableUltraSSD
    Defines whether to enable Ultra SSD.

.PARAMETER ProximityPlacementGroupId
    Defines the proximity placement group ID.

.PARAMETER HostId
    Defines the host ID.

.PARAMETER VmssId
    Defines the VMSS ID.

.PARAMETER Priority
    Defines the priority.

.PARAMETER EvictionPolicy
    Defines the eviction policy.

.PARAMETER MaxPrice
    Defines the maximum price.

.PARAMETER EncryptionAtHost
    Defines whether to enable encryption at host.

.PARAMETER HostGroupId
    Defines the host group ID.

.PARAMETER SshKeyName
    Defines the SSH key name.

.PARAMETER GenerateSshKey
    Defines whether to generate an SSH key.

.PARAMETER CapacityReservationGroupId
    Defines the capacity reservation group ID.

.PARAMETER UserData
    Defines the user data.

.PARAMETER ImageReferenceId
    Defines the image reference ID.

.PARAMETER PlatformFaultDomain
    Defines the platform fault domain.

.PARAMETER HibernationEnabled
    Defines whether hibernation is enabled.

.PARAMETER vCPUCountAvailable
    Defines the available vCPU count.

.PARAMETER vCPUCountPerCore
    Defines the vCPU count per core.

.PARAMETER DiskControllerType
    Defines the disk controller type.

.PARAMETER SharedGalleryImageId
    Defines the shared gallery image ID.

.PARAMETER SecurityType
    Defines the security type.

.PARAMETER EnableVtpm
    Defines whether to enable VTPM.

.PARAMETER EnableSecureBoot
    Defines whether to enable secure boot.

.EXAMPLE
    .\az-cli-create-windows-vm.ps1 -Name "myVm" -UserName "azureuser" -Password (ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force) -ResourceGroup "myResourceGroup" -Location "eastus" -Image "Win2022Datacenter"

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
    https://learn.microsoft.com/en-us/cli/azure/vm

.COMPONENT
    Azure CLI Virtual Machines

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure VM")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "The admin username for the Azure VM")]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,

    [Parameter(Mandatory = $true, HelpMessage = "The admin password for the Azure VM")]
    [ValidateNotNullOrEmpty()]
    [securestring]$Password,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The Azure region for the VM")]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral',
        'asia', 'asiapacific', 'australia', 'brazil',
        'canada', 'europe', 'france',
        'global', 'india', 'japan', 'korea',
        'norway', 'singapore', 'southafrica', 'sweden',
        'switzerland', 'unitedstates', 'northcentralus', 'westus',
        'japanwest', 'centraluseuap', 'eastus2euap', 'westcentralus',
        'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast',
        'koreasouth', 'southindia', 'westindia', 'canadaeast',
        'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest',
        'ukwest', 'uaecentral', 'brazilsoutheast'
    )]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Zone,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpSku,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NetworkInterfaceDeleteOption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NetworkName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AddressPrefix,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetAddressPrefix,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpAddressName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DomainNameLabel,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AllocationMethod,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityGroupName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$OpenPorts,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Image,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Size,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AvailabilitySetName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SystemAssignedIdentity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$UserAssignedIdentity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OSDiskDeleteOption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$DataDiskSizeInGb,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DataDiskDeleteOption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableUltraSSD,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ProximityPlacementGroupId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$HostId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VmssId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Priority,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EvictionPolicy,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [double]$MaxPrice,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EncryptionAtHost,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$HostGroupId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SshKeyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$GenerateSshKey,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$CapacityReservationGroupId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$UserData,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ImageReferenceId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$PlatformFaultDomain,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$HibernationEnabled,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$vCPUCountAvailable,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$vCPUCountPerCore,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DiskControllerType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedGalleryImageId,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableVtpm,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableSecureBoot
)

# Splatting parameters for better readability
$parameters = @{
    Name        = $Name
    Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
    ResourceGroup = $ResourceGroup
    Location    = $Location
}

if ($EdgeZone) {
    $parameters['EdgeZone'] = $EdgeZone
}

if ($Zone) {
    $parameters['Zone'] = $Zone
}

if ($PublicIpSku) {
    $parameters['PublicIpSku'] = $PublicIpSku
}

if ($NetworkInterfaceDeleteOption) {
    $parameters['NetworkInterfaceDeleteOption'] = $NetworkInterfaceDeleteOption
}

if ($NetworkName) {
    $parameters['VirtualNetWorkName'] = $NetworkName
}

if ($AddressPrefix) {
    $parameters['AddressPrefix'] = $AddressPrefix
}

if ($SubnetName) {
    $parameters['SubnetName'] = $SubnetName
}

if ($SubnetAddressPrefix) {
    $parameters['SubnetAddressPrefix'] = $SubnetAddressPrefix
}

if ($PublicIpAddressName) {
    $parameters['PublicIpAddressName'] = $PublicIpAddressName
}

if ($DomainNameLabel) {
    $parameters['DomainNameLabel'] = $DomainNameLabel
}

if ($AllocationMethod) {
    $parameters['AllocationMethod'] = $AllocationMethod
}

if ($SecurityGroupName) {
    $parameters['SecurityGroupName'] = $SecurityGroupName
}

if ($OpenPorts) {
    $parameters['OpenPorts'] = $OpenPorts
}

if ($Image) {
    $parameters['Image'] = $Image
}

if ($Size) {
    $parameters['Size'] = $Size
}

if ($AvailabilitySetName) {
    $parameters['AvailabilitySetName'] = $AvailabilitySetName
}

if ($SystemAssignedIdentity) {
    $parameters['SystemAssignedIdentity'] = $SystemAssignedIdentity
}

if ($UserAssignedIdentity) {
    $parameters['UserAssignedIdentity'] = $UserAssignedIdentity
}

if ($OSDiskDeleteOption) {
    $parameters['OSDiskDeleteOption'] = $OSDiskDeleteOption
}

if ($DataDiskSizeInGb) {
    $parameters['DataDiskSizeInGb'] = $DataDiskSizeInGb
}

if ($DataDiskDeleteOption) {
    $parameters['DataDiskDeleteOption'] = $DataDiskDeleteOption
}

if ($EnableUltraSSD) {
    $parameters['EnableUltraSSD'] = $EnableUltraSSD
}

if ($ProximityPlacementGroupId) {
    $parameters['ProximityPlacementGroupId'] = $ProximityPlacementGroupId
}

if ($HostId) {
    $parameters['HostId'] = $HostId
}

if ($VmssId) {
    $parameters['VmssId'] = $VmssId
}

if ($Priority) {
    $parameters['Priority'] = $Priority
}

if ($EvictionPolicy) {
    $parameters['EvictionPolicy'] = $EvictionPolicy
}

if ($MaxPrice) {
    $parameters['MaxPrice'] = $MaxPrice
}

if ($EncryptionAtHost) {
    $parameters['EncryptionAtHost'] = $EncryptionAtHost
}

if ($HostGroupId) {
    $parameters['HostGroupId'] = $HostGroupId
}

if ($SshKeyName) {
    $parameters['SshKeyName'] = $SshKeyName
}

if ($GenerateSshKey) {
    $parameters['GenerateSshKey'] = $GenerateSshKey
}

if ($CapacityReservationGroupId) {
    $parameters['CapacityReservationGroupId'] = $CapacityReservationGroupId
}

if ($UserData) {
    $parameters['UserData'] = $UserData
}

if ($ImageReferenceId) {
    $parameters['ImageReferenceId'] = $ImageReferenceId
}

if ($PlatformFaultDomain) {
    $parameters['PlatformFaultDomain'] = $PlatformFaultDomain
}

if ($HibernationEnabled) {
    $parameters['HibernationEnabled'] = $HibernationEnabled
}

if ($vCPUCountAvailable) {
    $parameters['vCPUCountAvailable'] = $vCPUCountAvailable
}

if ($vCPUCountPerCore) {
    $parameters['vCPUCountPerCore'] = $vCPUCountPerCore
}

if ($DiskControllerType) {
    $parameters['DiskControllerType'] = $DiskControllerType
}

if ($SharedGalleryImageId) {
    $parameters['SharedGalleryImageId'] = $SharedGalleryImageId
}

if ($SecurityType) {
    $parameters['SecurityType'] = $SecurityType
}

if ($EnableVtpm) {
    $parameters['EnableVtpm'] = $EnableVtpm
}

if ($EnableSecureBoot) {
    $parameters['EnableSecureBoot'] = $EnableSecureBoot
}


# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the VM
    New-AzVM @parameters -Verbose

    Get-AzVM -ResourceGroup $resourceGroup -Name $name

    # Get the public IP of the VM
    $publicIp = Get-AzPublicIpAddress -Name $parameters.PublicIpAddressName -ResourceGroup $parameters.ResourceGroup

    # Output the public IP details
    $publicIp | Select-Object -Property Name, IpAddress, @{label='FQDN';expression={$_.DnsSettings.Fqdn}}

    # Output the result
    Write-Host "✅ Azure VM '$($parameters.Name)' created successfully." -ForegroundColor Green
    Write-Host "   Public IP address: $($publicIp.IpAddress)" -ForegroundColor White
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
