<#
.SYNOPSIS
    Automates the creation of Azure Virtual Machines.

.DESCRIPTION
    This script automates the creation of multiple Azure Virtual Machines with a wide range of customizable configurations.
    It generates VM names based on a specific prefix and handles VM numbering automatically.
    Parameters allow detailed customization of each VM, covering network settings, sizes, identities, storage, and security features.

.NOTES
    Requires Az PowerShell module to execute Azure operations.
    Supports a wide variety of parameters for fine-grained control over VM creation.
    Error handling is implemented to provide informative failure messages and ensure robust operation.

.COMPONENT
    Az PowerShell Module

.LINK
    https://docs.microsoft.com/en-us/powershell/azure/

.PARAMETER NumberOfVMs
    Defines the number of virtual machines to create.

.PARAMETER NamePrefix
    Prefix for the VM name to facilitate numbering.

.PARAMETER Digits
    Number of digits for VM numbering.

.PARAMETER UserName
    Username for the VM administrator.

.PARAMETER Password
    Password for VM administration stored as a secure string.

.PARAMETER ResourceGroup
    Azure Resource Group where the VMs will be created.

.PARAMETER Location
    Azure region where the VMs are deployed.

.PARAMETER EdgeZone
    Specifies the edge zone for deployment.

.PARAMETER Zone
    Specifies availability zone for the VM.

.PARAMETER PublicIpSku
    The Public IP SKU to use, if creating a public IP.

.PARAMETER NetworkInterfaceDeleteOption
    Specifies the delete option for the network interface.

.PARAMETER NetworkName
    Name of the virtual network to attach to the VMs.

.PARAMETER AddressPrefix
    Address prefix for the virtual network.

.PARAMETER SubnetName
    Name of the subnet within the virtual network.

.PARAMETER SubnetAddressPrefix
    Address prefix of the subnet.

.PARAMETER PublicIpAddress
    Switch to create a public IP for each VM.

.PARAMETER DomainNameLabel
    Label for the DNS domain name.

.PARAMETER AllocationMethod
    Method to allocate public IP (static or dynamic).

.PARAMETER SecurityGroupName
    Name of the network security group.

.PARAMETER OpenPorts
    Ports to open on the VM's network security group.

.PARAMETER Image
    Image used to create the VM.

.PARAMETER Size
    Size of the VM to be deployed.

.PARAMETER AvailabilitySetName
    Name of the availability set for the VMs.

.PARAMETER SystemAssignedIdentity
    Assigns a system identity to the VM.

.PARAMETER UserAssignedIdentity
    Assigns a user-defined identity to the VM.

.PARAMETER OSDiskDeleteOption
    Delete option for the OS disk.

.PARAMETER DataDiskSizeInGb
    Specifies the size in GB for the data disk.

.PARAMETER DataDiskDeleteOption
    Delete option for data disks.

.PARAMETER EnableUltraSSD
    Switch to enable UltraSSD on the VMs.

.PARAMETER ProximityPlacementGroupId
    ID of the proximity placement group.

.PARAMETER HostId
    ID of the host for the VM.

.PARAMETER VmssId
    ID of the virtual machine scale set.

.PARAMETER Priority
    Specifies the priority of the VM.

.PARAMETER EvictionPolicy
    Defines eviction policy for low-priority VMs.

.PARAMETER MaxPrice
    Maximum price willing to pay per VM if using spot VMs.

.PARAMETER EncryptionAtHost
    Switch to enable host-based encryption.

.PARAMETER HostGroupId
    ID of the host group.

.PARAMETER SshKeyName
    Name of the SSH key to be used.

.PARAMETER GenerateSshKey
    Switch to generate SSH keys.

.PARAMETER CapacityReservationGroupId
    ID of the capacity reservation group.

.PARAMETER UserData
    Custom data to setup VM.

.PARAMETER ImageReferenceId
    ID of the image reference from the shared gallery.

.PARAMETER PlatformFaultDomain
    Fault domain for the VM.

.PARAMETER HibernationEnabled
    Switch to enable hibernation on the VM.

.PARAMETER vCPUCountAvailable
    Number of available virtual CPUs.

.PARAMETER vCPUCountPerCore
    Number of virtual CPUs per core.

.PARAMETER DiskControllerType
    Type of the disk controller.

.PARAMETER SharedGalleryImageId
    ID for the shared gallery image.

.PARAMETER SecurityType
    Type of security features enabled on the VM.

.PARAMETER EnableVtpm
    Enables vTPM on the VM.

.PARAMETER EnableSecureBoot
    Enables secure boot on the VM.
    
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$NumberOfVMs,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$NamePrefix,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Digits,

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
    [Switch]$PublicIpAddress,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DomainNameLabel,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$AllocationMethod,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityGroupName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$OpenPorts,

    [Parameter(Mandatory=$false)]
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

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SecurityType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableVtpm,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [bool]$EnableSecureBoot
)


function Get-MaxVMNumberByPrefix {
    param (
        [string]$namePrefix,
        [int]$digits
    )

    # Validate the digits parameter to ensure it's a positive integer
    if ($digits -lt 1) {
        throw "The number of digits must be at least 1."
    }

    # Get all VMs in the subscription that start with the specific prefix
    $vms = Get-AzVM | Where-Object { $_.Name -like "$namePrefix*" }
    $maxNumber = 0

    foreach ($vm in $vms) {
        $endingNumber = [int]($vm.Name.Substring($namePrefix.Length))
        if ($endingNumber -gt $maxNumber) {
            $maxNumber = $endingNumber
        }
    }

    # Handle case if no VMs are found
    if ($maxNumber -eq 0) {
        return "No VMs found with the specified prefix."
    }



    # Output the formatted number
    return $maxNumber + 1
}

$nextVMnumber = Get-MaxVMNumberByPrefix -namePrefix $NamePrefix -digits $Digits

for ($i = 1; $i -le $NumberOfVMs; $i++) {
    # Format the number with leading zeros
    $formattedNumber = "{0:D$($digits)}" -f ($nextVMnumber)
    $vmname = ($NamePrefix+$formattedNumber)

    $parameters = @{
        Name        = $vmname
        Credential  = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $Password
        ResourceGroupName = $ResourceGroup
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

    if ($PublicIpAddress) {
        $parameters['PublicIpAddressName'] = "$($NamePrefix)$nextVMnumber-PublicIP"
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

        Get-AzVM -ResourceGroupName $resourceGroup -Name $vmname
        Write-Output "Azure VM '$($parameters.Name)' created successfully."
        if ($PublicIpAddress -and $parameters.PublicIpAddressName -and $ResourceGroup) {
            $publicIp = Get-AzPublicIpAddress -Name "$($parameters.PublicIpAddressName)" -ResourceGroupName $ResourceGroup
            Write-Output "Public IP address: $($publicIp.IpAddress)"
        } else {
            Write-Output "Public IP Address not created or parameters are not correctly set."
        }

        # Output the result
        Write-Output "Azure VM '$($parameters.Name)' created successfully."
        Write-Output "Public IP address: $($publicIp.IpAddress)"
    } catch {
        # Log the error to a file
        $errorMessage = "Error: $($_.Exception.Message)"
        Write-Output "Error message $errorMessage"

        # Write the error to the console
        Write-Error "Failed to create Azure VM: $($_.Exception.Message)"
    } finally {
        # Cleanup code if needed
        Write-Output "VM deployment is completed."
    }
    $nextVMnumber= $nextVMnumber + 1
}
