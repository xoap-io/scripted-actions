<#
.SYNOPSIS
    Automates the deployment and configuration of a Virtual Machine in Microsoft Azure.

.DESCRIPTION
    This script creates and configures a Virtual Machine (VM) within a specified Azure environment using provided credentials.
    It assigns a static IP, selects the latest OS image, and tags the VM for organizational purposes.

.PARAMETER Location
    Specifies the Azure region where the VM will be deployed.

.PARAMETER ImageID
    The image ID to use for the VM.

.PARAMETER VMSize
    The size of the Virtual Machine (e.g., 'Standard_D2s_v3').

.PARAMETER DiskSize
    Size of the disk in GB for the Virtual Machine.

.PARAMETER UserName
    Username for the VM's admin account.

.PARAMETER Password
    Password for the VM's admin account as a SecureString.

.PARAMETER VirtualNetworkName
    The name of the virtual network.

.PARAMETER SubnetName
    The name of the subnet.

.PARAMETER NetResourceGroup
    The name of the resource group containing the network resources.

.PARAMETER ResourceGroup
    The name of the resource group where the VM will be created.

.PARAMETER Tags
    A hashtable of tags to apply to the VM.

.EXAMPLE
    PS C:\> .\New-AzVm.ps1 -Location "westeurope" -ImageID "myImageId" -VMSize "Standard_D2s_v3" -DiskSize 128 -UserName "admin" -Password $securePass -VirtualNetworkName "MyVNet" -SubnetName "default" -NetResourceGroup "MyNetRG" -ResourceGroup "MyRG"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.Compute, Az.Network

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.compute/new-azvm

.COMPONENT
    Azure PowerShell Compute

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the VM will be deployed.")]
    [ValidateNotNullOrEmpty()]
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

    [Parameter(Mandatory=$true, HelpMessage = "The image ID to use for the VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$ImageID,

    [Parameter(Mandatory=$true, HelpMessage = "The size of the Virtual Machine (e.g., 'Standard_D2s_v3').")]
    [ValidateNotNullOrEmpty()]
    [string]$VMSize,

    [Parameter(Mandatory=$true, HelpMessage = "Size of the OS disk in GB.")]
    [ValidateNotNullOrEmpty()]
    [int]$DiskSize = 128,

    [Parameter(Mandatory=$true, HelpMessage = "Username for the VM admin account.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,

    [Parameter(Mandatory=$true, HelpMessage = "Password for the VM admin account as a SecureString.")]
    [ValidateNotNullOrEmpty()]
    [SecureString]$Password,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the virtual network.")]
    [ValidateNotNullOrEmpty()]
    [string]$VirtualNetworkName,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the subnet.")]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory=$true, HelpMessage = "The resource group containing the network resources.")]
    [ValidateNotNullOrEmpty()]
    [string]$NetResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The resource group where the VM will be created.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the VM.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

$ErrorActionPreference = "Stop"

# Configure the NIC with static IP
try {
    $nic = New-AzNetworkInterface -ResourceGroup $ResourceGroup `
        -Name ($VmName + '_nic0') `
        -Location $Location `
        -SubnetId $subnet.Id `
        -PrivateIpAddress $freeIpDetails.IpAddress -ErrorAction Stop

    if (-not $nic) {
        Write-Error "Failed to create the network interface."
        exit
    }
} catch {
    Write-Error "Error creating network interface: $_"
    exit
}

$SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential ($UserName, $SecurePassword)

# Create the VM configuration
try {
    $vmConfig = New-AzVMConfig -VMName $VmName -VMSize $VMSize | `
        Set-AzVMOperatingSystem -Windows -ComputerName $VmName -ProvisionVMAgent -EnableAutoUpdate `
            -Credential $Credential | `
        Set-AzVMSourceImage -PublisherName $osImage.PublisherName -Offer $osImage.Offer -Skus $osImage.Skus -Version $osImage.Version | `
        Set-AzVMOSDisk -CreateOption FromImage -DiskSizeInGB $DiskSize -Caching ReadWrite | `
        Add-AzVMNetworkInterface -Id $nic.Id -Primary
} catch {
    Write-Error "Error configuring the virtual machine: $_"
    exit
}

# Output the VM configuration to verify
Write-Output $vmConfig

# Create the VM
try {
    $virtualMachine = New-AzVM -ResourceGroup $ResourceGroup `
        -Location $Location `
        -VM $vmConfig -ErrorAction Stop
    Write-Output "AVD VM $VmName created successfully with static IP $IpAddress."
} catch {
    Write-Error "Error creating the virtual machine: $_"
    exit
}

# Assign tags to the VM
try {
    $VirtualMachine = Get-AzVM -ResourceGroup $ResourceGroup -Name $VMName
    Update-AzTag -ResourceId $VirtualMachine.Id -Tag $tags -Operation Merge
    Write-Output "Tags are added to the virtual machine: $_"

} catch {
    Write-Error "Error adding tags to the virtual machine: $_"
}
