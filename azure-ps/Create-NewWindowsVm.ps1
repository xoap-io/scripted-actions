<#

.SYNOPSIS
    Create a new Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure VM with the Azure PowerShell. The script creates a new Azure Resource Group, a new Azure VM, and a new Azure Public IP Address.
    The script also retrieves the public IP address of the VM.

.PARAMETER ResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER VmName
    Defines the name of the Azure VM.

.PARAMETER Location
    Defines the location of the Azure VM.

.PARAMETER ImageName
    Defines the name of the Azure VM image.

.PARAMETER PublicIpAddressName
    Defines the name of the Azure VM public IP address.

.PARAMETER VmUserName
    Defines the name of the Azure VM user.

.PARAMETER VmUserPassword
    Defines the password of the Azure VM user.

.PARAMETER OpenPorts
    Defines the open ports of the Azure VM.

.PARAMETER VmSize
    Defines the size of the Azure VM.

.PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

.EXAMPLE
    .\Create-NewWindowsVm.ps1 -AzResourceGroupName "myResourceGroup" -AzVmName "myVm" -AzLocation "eastus" -AzImageName "myImageName" -AzPublicIpAddressName "myPublicIpAddressName" -AzVmUserName "myVmUser" -AzVmUserPassword "myVmPassword" -AzOpenPorts 3389 -AzVmSize "Standard_D2s_v3"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.Compute

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azvm?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [securestring]$Password,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
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
    [ValidateSet(
        'Basic',
        'Standard'
    )]
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
    [ValidateSet(
        'Static',
        'Dynamic'
    )]
    [string]$AllocationMethod,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityGroupName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$OpenPorts,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false)]
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
    [ValidateSet(
        'Delete',
        'Detach'
    )]
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
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Windows_Client',
        'Windows_Server',
        'RHEL_BYOS',
        'SLES_BYOS'
    )]
    [string]$LicenseType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$VmssId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Regular',
        'Spot',
        'Low'
    )]
    [string]$Priority,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Deallocate',
        'Delete'
    )]
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
    [ValidateSet(
        'NVMe',
        'SCSI'
    )]
    [string]$DiskControllerType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SharedGalleryImageId,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'TrustedLaunch',
        'ConfidentialVM',
        'Standard'
    )]
    [string]$SecurityType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableVtpm,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnableSecureBoot
)

# Splatting parameters for better readability
$parameters = @{
    Name        = $Name
    Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
    ResourceGroupName = $ResourceGroup
    Location    = $Location
}

if ($EdgeZone) {
    $parameters['EdgeZone', $EdgeZone
}

if ($Zone) {
    $parameters['Zone', $Zone
}

if ($PublicIpSku) {
    $parameters['PublicIpSku', $PublicIpSku
}

if ($NetworkInterfaceDeleteOption) {
    $parameters['NetworkInterfaceDeleteOption', $NetworkInterfaceDeleteOption
}

if ($NetworkName) {
    $parameters['VirtualNetWorkName', $NetworkName
}

if ($AddressPrefix) {
    $parameters['AddressPrefix', $AddressPrefix
}

if ($SubnetName) {
    $parameters['SubnetName', $SubnetName
}

if ($SubnetAddressPrefix) {
    $parameters['SubnetAddressPrefix', $SubnetAddressPrefix
}

if ($PublicIpAddressName) {
    $parameters['PublicIpAddressName', $PublicIpAddressName
}

if ($DomainNameLabel) {
    $parameters['DomainNameLabel', $DomainNameLabel
}

if ($AllocationMethod) {
    $parameters['AllocationMethod', $AllocationMethod
}

if ($SecurityGroupName) {
    $parameters['SecurityGroupName', $SecurityGroupName
}

if ($OpenPorts) {
    $parameters['OpenPorts', $OpenPorts
}

if ($Image) {
    $parameters['Image', $Image
}

if ($Size) {
    $parameters['Size', $Size
}

if ($AvailabilitySetName) {
    $parameters['AvailabilitySetName', $AvailabilitySetName
}

if ($SystemAssignedIdentity) {
    $parameters['SystemAssignedIdentity', $SystemAssignedIdentity
}

if ($UserAssignedIdentity) {
    $parameters['UserAssignedIdentity', $UserAssignedIdentity
}

if ($OSDiskDeleteOption) {
    $parameters['OSDiskDeleteOption', $OSDiskDeleteOption
}

if ($DataDiskSizeInGb) {
    $parameters['DataDiskSizeInGb', $DataDiskSizeInGb
}

if ($DataDiskDeleteOption) {
    $parameters['DataDiskDeleteOption', $DataDiskDeleteOption
}

if ($EnableUltraSSD) {
    $parameters['EnableUltraSSD', $EnableUltraSSD
}

if ($ProximityPlacementGroupId) {
    $parameters['ProximityPlacementGroupId', $ProximityPlacementGroupId
}

if ($HostId) {
    $parameters['HostId', $HostId
}

if ($VmssId) {
    $parameters['VmssId', $VmssId
}

if ($Priority) {
    $parameters['Priority', $Priority
}

if ($EvictionPolicy) {
    $parameters['EvictionPolicy', $EvictionPolicy
}

if ($MaxPrice) {
    $parameters['MaxPrice', $MaxPrice
}

if ($EncryptionAtHost) {
    $parameters['EncryptionAtHost', $EncryptionAtHost
}

if ($HostGroupId) {
    $parameters['HostGroupId', $HostGroupId
}

if ($SshKeyName) {
    $parameters['SshKeyName', $SshKeyName
}

if ($GenerateSshKey) {
    $parameters['GenerateSshKey', $GenerateSshKey
}

if ($CapacityReservationGroupId) {
    $parameters['CapacityReservationGroupId', $CapacityReservationGroupId
}

if ($UserData) {
    $parameters['UserData', $UserData
}

if ($ImageReferenceId) {
    $parameters['ImageReferenceId', $ImageReferenceId
}

if ($PlatformFaultDomain) {
    $parameters['PlatformFaultDomain', $PlatformFaultDomain
}

if ($HibernationEnabled) {
    $parameters['HibernationEnabled', $HibernationEnabled
}

if ($vCPUCountAvailable) {
    $parameters['vCPUCountAvailable', $vCPUCountAvailable
}

if ($vCPUCountPerCore) {
    $parameters['vCPUCountPerCore', $vCPUCountPerCore
}

if ($DiskControllerType) {
    $parameters['DiskControllerType', $DiskControllerType
}

if ($SharedGalleryImageId) {
    $parameters['SharedGalleryImageId', $SharedGalleryImageId
}

if ($SecurityType) {
    $parameters['SecurityType', $SecurityType
}

if ($EnableVtpm) {
    $parameters['EnableVtpm', $EnableVtpm
}

if ($EnableSecureBoot) {
    $parameters['EnableSecureBoot', $EnableSecureBoot
}

if ($LicenseType) {
    $parameters['LicenseType', $LicenseType
}

if ($Confirm) {
    $parameters['Confirm', $Confirm
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the VM
    New-AzVM @parameters -Verbose

    Get-AzVM -ResourceGroupName $resourceGroup -Name $name

    # Get the public IP of the VM
    $publicIp = Get-AzPublicIpAddress -Name $parameters.PublicIpAddressName -ResourceGroup $parameters.ResourceGroup

    # Output the public IP details
    $publicIp | Select-Object -Property Name, IpAddress, @{label='FQDN';expression={$_.DnsSettings.Fqdn}}

    # Output the result
    Write-Output "Azure VM '$($parameters.Name)' created successfully."
    Write-Output "Public IP address: $($publicIp.IpAddress)"
} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"


    Write-Error "Failed to create Azure VM: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
