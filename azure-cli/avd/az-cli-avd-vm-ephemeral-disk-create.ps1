<#
.SYNOPSIS
    Create an Azure Virtual Machine with ephemeral OS disk using Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Machine with ephemeral OS disk configuration using the Azure CLI.
    Ephemeral OS disks are stored on the local VM storage and provide faster performance for stateless workloads.
    
    The script uses the Azure CLI command: az vm create

.PARAMETER ResourceGroup
    The name of the Azure Resource Group where the VM will be created.

.PARAMETER VMName
    The name of the Azure Virtual Machine to create.

.PARAMETER Image
    The VM image to use. Can be an image URN, custom image name, or marketplace image.

.PARAMETER Location
    The Azure region where the VM will be created (e.g., 'eastus', 'westus2').

.PARAMETER Size
    The size of the virtual machine (e.g., 'Standard_B2s', 'Standard_D2s_v3').

.PARAMETER EphemeralOSDiskPlacement
    Specifies where to place the ephemeral OS disk.
    Valid values: 'CacheDisk', 'ResourceDisk'

.PARAMETER OSDiskCaching
    The caching mode for the OS disk.
    Valid values: 'None', 'ReadOnly', 'ReadWrite'

.PARAMETER AdminUsername
    The administrator username for the VM.

.PARAMETER AuthenticationType
    The authentication type for the VM.
    Valid values: 'password', 'ssh'

.PARAMETER GenerateSSHKeys
    Generate SSH key pairs for Linux VMs (only applicable for SSH authentication).

.PARAMETER AdminPassword
    The administrator password for the VM (only applicable for password authentication).

.PARAMETER SubnetId
    The subnet resource ID where the VM will be placed.

.PARAMETER SecurityGroupType
    How to configure the network security group.
    Valid values: 'existing', 'new', 'none'

.PARAMETER Tags
    Tags to apply to the VM in the format 'key1=value1 key2=value2'.

.EXAMPLE
    .\az-cli-avd-vm-ephemeral-disk-create.ps1 -ResourceGroup "myRG" -VMName "myVM" -Image "Ubuntu2204" -Location "eastus"
    
    Creates a basic Ubuntu VM with ephemeral OS disk using default settings.

.EXAMPLE
    .\az-cli-avd-vm-ephemeral-disk-create.ps1 -ResourceGroup "myRG" -VMName "myVM" -Image "Win2022Datacenter" -Location "eastus" -Size "Standard_D2s_v3" -AuthenticationType "password" -AdminUsername "azureadmin" -AdminPassword "SecurePassword123!"
    
    Creates a Windows VM with ephemeral OS disk using password authentication.

.EXAMPLE
    .\az-cli-avd-vm-ephemeral-disk-create.ps1 -ResourceGroup "myRG" -VMName "myVM" -Image "Ubuntu2204" -Location "eastus" -EphemeralOSDiskPlacement "CacheDisk" -OSDiskCaching "ReadOnly" -GenerateSSHKeys -Tags "environment=test purpose=ephemeral"
    
    Creates an Ubuntu VM with ephemeral OS disk on cache disk with specific caching and tags.

.NOTES
    Author: Azure CLI Script
    Version: 2.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm

.LINK
    https://learn.microsoft.com/en-us/azure/virtual-machines/ephemeral-os-disks

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the Azure Virtual Machine")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9\-]{0,62}[a-zA-Z0-9]$|^[a-zA-Z0-9]$', ErrorMessage = "VM name must be 1-64 characters, start and end with alphanumeric, contain only letters, numbers, and hyphens")]
    [string]$VMName,

    [Parameter(Mandatory = $true, HelpMessage = "The VM image to use")]
    [ValidateNotNullOrEmpty()]
    [string]$Image,

    [Parameter(HelpMessage = "The Azure region where the VM will be created")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(HelpMessage = "The size of the virtual machine")]
    [ValidateNotNullOrEmpty()]
    [string]$Size = "Standard_B2s",

    [Parameter(HelpMessage = "The placement of the ephemeral OS disk")]
    [ValidateSet('CacheDisk', 'ResourceDisk')]
    [string]$EphemeralOSDiskPlacement = "ResourceDisk",

    [Parameter(HelpMessage = "The caching mode for the OS disk")]
    [ValidateSet('None', 'ReadOnly', 'ReadWrite')]
    [string]$OSDiskCaching = "ReadOnly",

    [Parameter(HelpMessage = "The administrator username for the VM")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 64)]
    [string]$AdminUsername = "azureuser",

    [Parameter(HelpMessage = "The authentication type for the VM")]
    [ValidateSet('password', 'ssh')]
    [string]$AuthenticationType = "ssh",

    [Parameter(HelpMessage = "Generate SSH key pairs for Linux VMs")]
    [switch]$GenerateSSHKeys,

    [Parameter(HelpMessage = "The administrator password for the VM")]
    [ValidateLength(12, 123)]
    [SecureString]$AdminPassword,

    [Parameter(HelpMessage = "The subnet resource ID where the VM will be placed")]
    [string]$SubnetId,

    [Parameter(HelpMessage = "How to configure the network security group")]
    [ValidateSet('existing', 'new', 'none')]
    [string]$SecurityGroupType,

    [Parameter(HelpMessage = "Tags to apply in the format 'key1=value1 key2=value2'")]
    [string]$Tags
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    # Check if Azure CLI is available
    if (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not found in PATH. Please install Azure CLI first."
    }

    # Check if user is logged in to Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }

    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green
    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan

    # Validate authentication type and password requirements
    if ($AuthenticationType -eq 'password' -and -not $AdminPassword) {
        throw "AdminPassword is required when AuthenticationType is 'password'"
    }

    # Build Azure CLI command parameters
    $azParams = @(
        'vm', 'create',
        '--resource-group', $ResourceGroup,
        '--name', $VMName,
        '--image', $Image,
        '--ephemeral-os-disk', 'true',
        '--ephemeral-os-disk-placement', $EphemeralOSDiskPlacement,
        '--os-disk-caching', $OSDiskCaching,
        '--admin-username', $AdminUsername,
        '--authentication-type', $AuthenticationType
    )

    # Add optional parameters
    if ($Location) { $azParams += '--location', $Location }
    if ($Size) { $azParams += '--size', $Size }
    if ($SubnetId) { $azParams += '--subnet', $SubnetId }
    if ($SecurityGroupType) { $azParams += '--nsg-rule', $SecurityGroupType }
    if ($Tags) { $azParams += '--tags', $Tags }

    # Handle authentication-specific parameters
    if ($AuthenticationType -eq 'ssh' -and $GenerateSSHKeys) {
        $azParams += '--generate-ssh-keys'
    }
    if ($AuthenticationType -eq 'password' -and $AdminPassword) {
        # Convert SecureString to plain text for Azure CLI
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AdminPassword))
        $azParams += '--admin-password', $plainPassword
    }

    Write-Host "Creating Azure Virtual Machine with ephemeral OS disk..." -ForegroundColor Yellow
    Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
    Write-Host "VM Name: $VMName" -ForegroundColor Cyan
    Write-Host "Image: $Image" -ForegroundColor Cyan
    Write-Host "Ephemeral OS Disk Placement: $EphemeralOSDiskPlacement" -ForegroundColor Cyan
    Write-Host "OS Disk Caching: $OSDiskCaching" -ForegroundColor Cyan

    # Execute Azure CLI command
    $result = & az @azParams 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Azure Virtual Machine created successfully!" -ForegroundColor Green
        
        # Parse and display VM information
        try {
            $vmInfo = $result | ConvertFrom-Json
            Write-Host "VM Details:" -ForegroundColor Cyan
            Write-Host "  Name: $($vmInfo.name)" -ForegroundColor White
            Write-Host "  Resource Group: $($vmInfo.resourceGroup)" -ForegroundColor White
            Write-Host "  Location: $($vmInfo.location)" -ForegroundColor White
            Write-Host "  VM Size: $($vmInfo.hardwareProfile.vmSize)" -ForegroundColor White
            Write-Host "  OS Type: $($vmInfo.storageProfile.osDisk.osType)" -ForegroundColor White
            Write-Host "  Ephemeral OS Disk: Enabled" -ForegroundColor White
            if ($vmInfo.networkProfile.networkInterfaces) {
                Write-Host "  Private IP: $($vmInfo.privateIps -join ', ')" -ForegroundColor White
                Write-Host "  Public IP: $($vmInfo.publicIps -join ', ')" -ForegroundColor White
            }
        }
        catch {
            Write-Host "VM created successfully, but could not parse detailed information." -ForegroundColor Yellow
        }
    }
    else {
        throw "Azure CLI command failed with exit code $LASTEXITCODE. Error: $($result -join "`n")"
    }
}
catch {
    Write-Host "✗ Failed to create Azure Virtual Machine" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
