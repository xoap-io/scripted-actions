<#
.SYNOPSIS
    Create a new Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell. The script creates a new Azure Resource Group,
    a new Azure VM, and a new Azure Public IP Address. The script also retrieves the public IP address of the VM.
    Uses New-AzVM from the Az.Compute module.

.PARAMETER Name
    Defines the name of the Azure VM.

.PARAMETER UserName
    Defines the name of the Azure VM user.

.PARAMETER Password
    Defines the password of the Azure VM user as a SecureString.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Location
    Defines the location of the Azure VM.

.PARAMETER EdgeZone
    Specifies the edge zone for the VM.

.PARAMETER Zone
    Specifies the availability zone for the VM.

.PARAMETER PublicIpSku
    SKU for the public IP address (Basic or Standard).

.PARAMETER NetworkInterfaceDeleteOption
    Specifies the delete option for the network interface.

.PARAMETER NetworkName
    Name of the virtual network.

.PARAMETER AddressPrefix
    Address prefix for the virtual network.

.PARAMETER SubnetName
    Name of the subnet.

.PARAMETER SubnetAddressPrefix
    Address prefix for the subnet.

.PARAMETER PublicIpAddressName
    Name of the public IP address.

.PARAMETER DomainNameLabel
    Domain name label for the public IP address.

.PARAMETER AllocationMethod
    IP allocation method (Static or Dynamic).

.PARAMETER SecurityGroupName
    Name of the network security group.

.PARAMETER OpenPorts
    Port number(s) to open on the VM.

.PARAMETER Image
    OS image for the VM.

.PARAMETER Size
    Size of the Azure VM.

.PARAMETER AvailabilitySetName
    Name of the availability set.

.PARAMETER SystemAssignedIdentity
    System-assigned managed identity for the VM.

.PARAMETER UserAssignedIdentity
    User-assigned managed identity for the VM.

.PARAMETER OSDiskDeleteOption
    Delete option for the OS disk.

.PARAMETER DataDiskSizeInGb
    Size of the data disk in GB.

.PARAMETER DataDiskDeleteOption
    Delete option for the data disk (Delete or Detach).

.PARAMETER EnableUltraSSD
    If specified, enables Ultra SSD for the VM.

.PARAMETER ProximityPlacementGroupId
    Resource ID of the proximity placement group.

.PARAMETER HostId
    Resource ID of the dedicated host.

.PARAMETER LicenseType
    License type for the VM (Windows_Client, Windows_Server, RHEL_BYOS, SLES_BYOS).

.PARAMETER VmssId
    Resource ID of the VM scale set.

.PARAMETER Priority
    Priority of the VM (Regular, Spot, Low).

.PARAMETER EvictionPolicy
    Eviction policy for Spot VMs (Deallocate or Delete).

.PARAMETER MaxPrice
    Maximum price for Spot VM billing.

.PARAMETER EncryptionAtHost
    If specified, enables encryption at host.

.PARAMETER HostGroupId
    Resource ID of the dedicated host group.

.PARAMETER SshKeyName
    Name of the SSH key.

.PARAMETER GenerateSshKey
    If specified, generates a new SSH key.

.PARAMETER CapacityReservationGroupId
    Resource ID of the capacity reservation group.

.PARAMETER UserData
    User data for the VM.

.PARAMETER ImageReferenceId
    Resource ID of the image reference.

.PARAMETER PlatformFaultDomain
    Platform fault domain for the VM.

.PARAMETER HibernationEnabled
    If specified, enables hibernation for the VM.

.PARAMETER vCPUCountAvailable
    Number of vCPUs available for the VM.

.PARAMETER vCPUCountPerCore
    Number of vCPUs per core for the VM.

.PARAMETER DiskControllerType
    Disk controller type (NVMe or SCSI).

.PARAMETER SharedGalleryImageId
    Resource ID of the shared gallery image.

.PARAMETER SecurityType
    Security type for the VM (TrustedLaunch, ConfidentialVM, Standard).

.PARAMETER EnableVtpm
    If specified, enables vTPM for the VM.

.PARAMETER EnableSecureBoot
    If specified, enables Secure Boot for the VM.

.EXAMPLE
    .\Create-NewWindowsVm.ps1 -Name "myVm" -UserName "myVmUser" -Password (ConvertTo-SecureString "myVmPassword" -AsPlainText -Force) -ResourceGroup "myResourceGroup" -Location "eastus" -SubnetName "default"

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
    https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azvm

.COMPONENT
    Azure PowerShell Compute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure VM user.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the password of the Azure VM user as a SecureString.")]
    [ValidateNotNullOrEmpty()]
    [securestring]$Password,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the location of the Azure VM.")]
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

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the edge zone for the VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$EdgeZone,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the availability zone for the VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$Zone,

    [Parameter(Mandatory = $false, HelpMessage = "SKU for the public IP address (Basic or Standard).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Basic', 'Standard')]
    [string]$PublicIpSku,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the delete option for the network interface.")]
    [ValidateNotNullOrEmpty()]
    [string]$NetworkInterfaceDeleteOption,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [string]$NetworkName,

    [Parameter(Mandatory = $false, HelpMessage = "Address prefix for the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [string]$AddressPrefix,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the subnet.")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory = $false, HelpMessage = "Address prefix for the subnet.")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetAddressPrefix,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the public IP address.")]
    [ValidateNotNullOrEmpty()]
    [string]$PublicIpAddressName,

    [Parameter(Mandatory = $false, HelpMessage = "Domain name label for the public IP address.")]
    [ValidateNotNullOrEmpty()]
    [string]$DomainNameLabel,

    [Parameter(Mandatory = $false, HelpMessage = "IP allocation method (Static or Dynamic).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Static', 'Dynamic')]
    [string]$AllocationMethod,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the network security group.")]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityGroupName,

    [Parameter(Mandatory = $false, HelpMessage = "Port number(s) to open on the VM.")]
    [ValidateNotNullOrEmpty()]
    [int]$OpenPorts,

    [Parameter(Mandatory = $false, HelpMessage = "OS image for the VM.")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Win2022AzureEdition',
        'Win2022AzureEditionCore',
        'Win2019Datacenter',
        'Win2016Datacenter',
        'Win2012R2Datacenter',
        'Win2012Datacenter',
        'Ubuntu2204',
        'CentOS85Gen2',
        'Debian11',
        'OpenSuseLeap154Gen2',
        'RHELRaw8LVMGen2',
        'SuseSles15SP3',
        'FlatcarLinuxFreeGen2'
    )]
    [string]$Image,

    [Parameter(Mandatory = $false, HelpMessage = "Size of the Azure VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$Size,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the availability set.")]
    [ValidateNotNullOrEmpty()]
    [string]$AvailabilitySetName,

    [Parameter(Mandatory = $false, HelpMessage = "System-assigned managed identity for the VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$SystemAssignedIdentity,

    [Parameter(Mandatory = $false, HelpMessage = "User-assigned managed identity for the VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserAssignedIdentity,

    [Parameter(Mandatory = $false, HelpMessage = "Delete option for the OS disk.")]
    [ValidateNotNullOrEmpty()]
    [string]$OSDiskDeleteOption,

    [Parameter(Mandatory = $false, HelpMessage = "Size of the data disk in GB.")]
    [ValidateNotNullOrEmpty()]
    [int]$DataDiskSizeInGb,

    [Parameter(Mandatory = $false, HelpMessage = "Delete option for the data disk (Delete or Detach).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Delete', 'Detach')]
    [string]$DataDiskDeleteOption,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, enables Ultra SSD for the VM.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableUltraSSD,

    [Parameter(Mandatory = $false, HelpMessage = "Resource ID of the proximity placement group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ProximityPlacementGroupId,

    [Parameter(Mandatory = $false, HelpMessage = "Resource ID of the dedicated host.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostId,

    [Parameter(Mandatory = $false, HelpMessage = "License type for the VM (Windows_Client, Windows_Server, RHEL_BYOS, SLES_BYOS).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Windows_Client', 'Windows_Server', 'RHEL_BYOS', 'SLES_BYOS')]
    [string]$LicenseType,

    [Parameter(Mandatory = $false, HelpMessage = "Resource ID of the VM scale set.")]
    [ValidateNotNullOrEmpty()]
    [string]$VmssId,

    [Parameter(Mandatory = $false, HelpMessage = "Priority of the VM (Regular, Spot, Low).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Regular', 'Spot', 'Low')]
    [string]$Priority,

    [Parameter(Mandatory = $false, HelpMessage = "Eviction policy for Spot VMs (Deallocate or Delete).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Deallocate', 'Delete')]
    [string]$EvictionPolicy,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum price for Spot VM billing.")]
    [ValidateNotNullOrEmpty()]
    [double]$MaxPrice,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, enables encryption at host.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EncryptionAtHost,

    [Parameter(Mandatory = $false, HelpMessage = "Resource ID of the dedicated host group.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostGroupId,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the SSH key.")]
    [ValidateNotNullOrEmpty()]
    [string]$SshKeyName,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, generates a new SSH key.")]
    [ValidateNotNullOrEmpty()]
    [switch]$GenerateSshKey,

    [Parameter(Mandatory = $false, HelpMessage = "Resource ID of the capacity reservation group.")]
    [ValidateNotNullOrEmpty()]
    [string]$CapacityReservationGroupId,

    [Parameter(Mandatory = $false, HelpMessage = "User data for the VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserData,

    [Parameter(Mandatory = $false, HelpMessage = "Resource ID of the image reference.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageReferenceId,

    [Parameter(Mandatory = $false, HelpMessage = "Platform fault domain for the VM.")]
    [ValidateNotNullOrEmpty()]
    [int]$PlatformFaultDomain,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, enables hibernation for the VM.")]
    [ValidateNotNullOrEmpty()]
    [switch]$HibernationEnabled,

    [Parameter(Mandatory = $false, HelpMessage = "Number of vCPUs available for the VM.")]
    [ValidateNotNullOrEmpty()]
    [int]$vCPUCountAvailable,

    [Parameter(Mandatory = $false, HelpMessage = "Number of vCPUs per core for the VM.")]
    [ValidateNotNullOrEmpty()]
    [int]$vCPUCountPerCore,

    [Parameter(Mandatory = $false, HelpMessage = "Disk controller type (NVMe or SCSI).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('NVMe', 'SCSI')]
    [string]$DiskControllerType,

    [Parameter(Mandatory = $false, HelpMessage = "Resource ID of the shared gallery image.")]
    [ValidateNotNullOrEmpty()]
    [string]$SharedGalleryImageId,

    [Parameter(Mandatory = $false, HelpMessage = "Security type for the VM (TrustedLaunch, ConfidentialVM, Standard).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('TrustedLaunch', 'ConfidentialVM', 'Standard')]
    [string]$SecurityType,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, enables vTPM for the VM.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableVtpm,

    [Parameter(Mandatory = $false, HelpMessage = "If specified, enables Secure Boot for the VM.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableSecureBoot
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name           = $Name
    Credential     = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
    ResourceGroupName = $ResourceGroup
    Location       = $Location
}

if ($EdgeZone) { $parameters['EdgeZone'] = $EdgeZone }
if ($Zone) { $parameters['Zone'] = $Zone }
if ($PublicIpSku) { $parameters['PublicIpSku'] = $PublicIpSku }
if ($NetworkInterfaceDeleteOption) { $parameters['NetworkInterfaceDeleteOption'] = $NetworkInterfaceDeleteOption }
if ($NetworkName) { $parameters['VirtualNetWorkName'] = $NetworkName }
if ($AddressPrefix) { $parameters['AddressPrefix'] = $AddressPrefix }
if ($SubnetName) { $parameters['SubnetName'] = $SubnetName }
if ($SubnetAddressPrefix) { $parameters['SubnetAddressPrefix'] = $SubnetAddressPrefix }
if ($PublicIpAddressName) { $parameters['PublicIpAddressName'] = $PublicIpAddressName }
if ($DomainNameLabel) { $parameters['DomainNameLabel'] = $DomainNameLabel }
if ($AllocationMethod) { $parameters['AllocationMethod'] = $AllocationMethod }
if ($SecurityGroupName) { $parameters['SecurityGroupName'] = $SecurityGroupName }
if ($OpenPorts) { $parameters['OpenPorts'] = $OpenPorts }
if ($Image) { $parameters['Image'] = $Image }
if ($Size) { $parameters['Size'] = $Size }
if ($AvailabilitySetName) { $parameters['AvailabilitySetName'] = $AvailabilitySetName }
if ($SystemAssignedIdentity) { $parameters['SystemAssignedIdentity'] = $SystemAssignedIdentity }
if ($UserAssignedIdentity) { $parameters['UserAssignedIdentity'] = $UserAssignedIdentity }
if ($OSDiskDeleteOption) { $parameters['OSDiskDeleteOption'] = $OSDiskDeleteOption }
if ($DataDiskSizeInGb) { $parameters['DataDiskSizeInGb'] = $DataDiskSizeInGb }
if ($DataDiskDeleteOption) { $parameters['DataDiskDeleteOption'] = $DataDiskDeleteOption }
if ($EnableUltraSSD) { $parameters['EnableUltraSSD'] = $EnableUltraSSD }
if ($ProximityPlacementGroupId) { $parameters['ProximityPlacementGroupId'] = $ProximityPlacementGroupId }
if ($HostId) { $parameters['HostId'] = $HostId }
if ($VmssId) { $parameters['VmssId'] = $VmssId }
if ($Priority) { $parameters['Priority'] = $Priority }
if ($EvictionPolicy) { $parameters['EvictionPolicy'] = $EvictionPolicy }
if ($MaxPrice) { $parameters['MaxPrice'] = $MaxPrice }
if ($EncryptionAtHost) { $parameters['EncryptionAtHost'] = $EncryptionAtHost }
if ($HostGroupId) { $parameters['HostGroupId'] = $HostGroupId }
if ($SshKeyName) { $parameters['SshKeyName'] = $SshKeyName }
if ($GenerateSshKey) { $parameters['GenerateSshKey'] = $GenerateSshKey }
if ($CapacityReservationGroupId) { $parameters['CapacityReservationGroupId'] = $CapacityReservationGroupId }
if ($UserData) { $parameters['UserData'] = $UserData }
if ($ImageReferenceId) { $parameters['ImageReferenceId'] = $ImageReferenceId }
if ($PlatformFaultDomain) { $parameters['PlatformFaultDomain'] = $PlatformFaultDomain }
if ($HibernationEnabled) { $parameters['HibernationEnabled'] = $HibernationEnabled }
if ($vCPUCountAvailable) { $parameters['vCPUCountAvailable'] = $vCPUCountAvailable }
if ($vCPUCountPerCore) { $parameters['vCPUCountPerCore'] = $vCPUCountPerCore }
if ($DiskControllerType) { $parameters['DiskControllerType'] = $DiskControllerType }
if ($SharedGalleryImageId) { $parameters['SharedGalleryImageId'] = $SharedGalleryImageId }
if ($SecurityType) { $parameters['SecurityType'] = $SecurityType }
if ($EnableVtpm) { $parameters['EnableVtpm'] = $EnableVtpm }
if ($EnableSecureBoot) { $parameters['EnableSecureBoot'] = $EnableSecureBoot }
if ($LicenseType) { $parameters['LicenseType'] = $LicenseType }

try {
    # Create the VM
    New-AzVM @parameters -Verbose

    Get-AzVM -ResourceGroupName $ResourceGroup -Name $Name

    # Get the public IP of the VM
    $publicIp = Get-AzPublicIpAddress -Name $parameters.PublicIpAddressName -ResourceGroupName $parameters.ResourceGroupName

    # Output the public IP details
    $publicIp | Select-Object -Property Name, IpAddress, @{label = 'FQDN'; expression = { $_.DnsSettings.Fqdn } }

    # Output the result
    Write-Host "✅ Azure VM '$($parameters.Name)' created successfully." -ForegroundColor Green
    Write-Host "✅ Public IP address: $($publicIp.IpAddress)" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
