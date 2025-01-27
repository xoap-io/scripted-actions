<#
.SYNOPSIS
    Automates the deployment and configuration of a Virtual Machine in Microsoft Azure.

.DESCRIPTION
    This script creates and configures a Virtual Machine (VM) within a specified Azure environment using provided credentials.
    It assigns a static IP, selects the latest OS image, and tags the VM for organizational purposes.

.PARAMETER Location
    Specifies the Azure region where the VM will be deployed. Examples include 'eastus', 'westeurope', etc.

.PARAMETER OS
    Specifies the operating system for the VM. Allowed values are 'Windows10' or 'Windows11'.

.PARAMETER DeploymentEnvironment
    The environment for deployment specifying 'Prod' or 'Dev' to configure specific settings and resources.

.PARAMETER VMSize
    The size of the Virtual Machine (e.g., 'Standard_D2s_v3').

.PARAMETER DiskSize
    Size of the disk in GB for the Virtual Machine.

.PARAMETER UserName
    Username for the VM's admin account.

.PARAMETER Password
    Password for the VM's admin account.

.NOTES
    Author: Sinisa Sokolic, Ante Mlinarevic
    Date: August 27, 2024
    Version: 1.0
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
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

     [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ImageID,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$VMSize,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int]$DiskSize = 128,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$Password,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$VirtualNetworkName,
    
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$SubnetName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$NetResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

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
