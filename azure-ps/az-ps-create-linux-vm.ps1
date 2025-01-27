<#
.SYNOPSIS
    Create a new Linux Azure VM with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Linux Azure VM with the Azure PowerShell.
    The script uses the Azure PowerShell to create the specified Linux Azure VM.
    The script uses the following Azure PowerShell command:
    New-AzVM -ResourceGroup $AzResourceGroup -Name $AzVmName -Location $AzLocation -Image $AzImageName -PublicIpAddressName $AzPublicIpAddressName -OpenPorts $AzOpenPorts -Size $AzVmSize
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

.PARAMETER AzDebug
    Increase logging verbosity to show all debug logs.

.PARAMETER AzOnlyShowErrors
    Only show errors, suppressing warnings.

.PARAMETER AzOutput
    Output format.

.PARAMETER AzQuery
    JMESPath query string.

.PARAMETER AzVerbose
    Increase logging verbosity.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

.EXAMPLE
    .\az-ps-create-linux-vm.ps1 -AzResourceGroup "myResourceGroup" -AzVmName "myVm" -AzLocation "westus" -AzImageName "UbuntuLTS" -AzPublicIpAddressName "myPublicIP" -AzOpenPorts 22 -AzVmSize "Standard_B1s"

.NOTES
    Ensure that Azure PowerShell is installed and authenticated before running the script.
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure PowerShell

.LINK
    https://learn.microsoft.com/en-us/powershell/azure/new-azureps
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzLocation,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzPublicIpAddressName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [int]$AzOpenPorts,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmSize,

    [Parameter(Mandatory=$false)]
    [string]$AzSshKeyName = "mySshKey"
)

# Splatting parameters for better readability
$parameters = @{
    ResourceGroup    = $AzResourceGroup
    Name                 = $AzVmName
    Location             = $AzLocation
    Image                = $AzImageName
    PublicIpAddressName  = $AzPublicIpAddressName
    OpenPorts            = $AzOpenPorts
    Size                 = $AzVmSize
    SshKeyName           = $AzSshKeyName
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the VM
    New-AzVm @parameters

    # Output the result
    Write-Output "Azure Linux VM created successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"


    Write-Error "Failed to create Azure Linux VM: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
