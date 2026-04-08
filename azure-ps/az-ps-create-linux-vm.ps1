<#
.SYNOPSIS
    Create a new Linux Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Linux Azure VM with the Azure PowerShell.
    The script uses the Azure PowerShell to create the specified Linux Azure VM.
    The script uses the following Azure PowerShell command:
    New-AzVM -ResourceGroupName $AzResourceGroup -Name $AzVmName -Location $AzLocation -Image $AzImageName -PublicIpAddressName $AzPublicIpAddressName -OpenPorts $AzOpenPorts -Size $AzVmSize
    The script sets the ErrorActionPreference to Stop to handle errors properly.

.PARAMETER AzResourceGroup
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

.EXAMPLE
    .\az-ps-create-linux-vm.ps1 -AzResourceGroup "myResourceGroup" -AzVmName "myVm" -AzLocation "westus" -AzImageName "UbuntuLTS" -AzPublicIpAddressName "myPublicIP" -AzOpenPorts 22 -AzVmSize "Standard_B1s"

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
    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the location of the Azure VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzLocation,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure VM image.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageName,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure VM public IP address.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzPublicIpAddressName,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the open ports of the Azure VM.")]
    [ValidateNotNullOrEmpty()]
    [int]$AzOpenPorts,

    [Parameter(Mandatory = $true, HelpMessage = "Defines the size of the Azure VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmSize,

    [Parameter(Mandatory = $false, HelpMessage = "Defines the name of the SSH key.")]
    [string]$AzSshKeyName = "mySshKey"
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ResourceGroupName   = $AzResourceGroup
    Name                = $AzVmName
    Location            = $AzLocation
    Image               = $AzImageName
    PublicIpAddressName = $AzPublicIpAddressName
    OpenPorts           = $AzOpenPorts
    Size                = $AzVmSize
    SshKeyName          = $AzSshKeyName
}

try {
    # Create the VM
    New-AzVm @parameters

    # Output the result
    Write-Host "✅ Azure Linux VM created successfully." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
