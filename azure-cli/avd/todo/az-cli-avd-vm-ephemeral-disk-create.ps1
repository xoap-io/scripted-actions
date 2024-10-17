<#
.SYNOPSIS
    Create an Azure Virtual Machine with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Machine with the Azure CLI.
    The script uses the following Azure CLI command:
    az vm create --resource-group $AzResourceGroupName --name $AzVMName --image $AzImageName

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzVMName
    Defines the name of the Azure Virtual Machine.

.PARAMETER AzImageName
    Defines the name of the image to use for the VM.

.PARAMETER AzEphemeralOSDisk
    Specifies whether to use an ephemeral OS disk.

.PARAMETER AzEphemeralOSDiskPlacement
    Specifies the placement of the ephemeral OS disk.

.PARAMETER AzOSDiskCaching
    Specifies the caching mode of the OS disk.

.PARAMETER AzAdminUsername
    Specifies the admin username for the VM.

.PARAMETER AzGenerateSSHKeys
    Specifies whether to generate SSH keys.

.PARAMETER AzSubscription
    Name or ID of subscription.

.PARAMETER AzDefaultProfile
    The default profile.

.PARAMETER WhatIf
    Shows what would happen if the cmdlet runs. The cmdlet is not run.

.PARAMETER Confirm
    Prompts you for confirmation before running the cmdlet.

.EXAMPLE
    .\az-cli-vm-create.ps1 -AzResourceGroupName "MyResourceGroup" -AzVMName "MyVM" -AzImageName "UbuntuLTS"

.NOTES
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroupName = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVMName = "myVM",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzImageName = "UbuntuLTS",

    [Parameter(Mandatory=$false)]
    [bool]$AzEphemeralOSDisk = $true,

    [Parameter(Mandatory=$false)]
    [string]$AzEphemeralOSDiskPlacement = "ResourceDisk",

    [Parameter(Mandatory=$false)]
    [string]$AzOSDiskCaching = "ReadOnly",

    [Parameter(Mandatory=$false)]
    [string]$AzAdminUsername = "azureuser",

    [Parameter(Mandatory=$false)]
    [bool]$AzGenerateSSHKeys = $true,

    [Parameter(Mandatory=$false)]
    [string]$AzSubscription,


)

# Splatting parameters for better readability
$parameters = @{
    resource_group              = $AzResourceGroupName
    name                        = $AzVMName
    image                       = $AzImageName
    ephemeral_os_disk           = $AzEphemeralOSDisk
    ephemeral_os_disk_placement = $AzEphemeralOSDiskPlacement
    os_disk_caching             = $AzOSDiskCaching
    admin_username              = $AzAdminUsername
    generate_ssh_keys           = $AzGenerateSSHKeys
    subscription                = $AzSubscription
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the Azure Virtual Machine
    az vm create @parameters

    # Output the result
    Write-Output "Azure Virtual Machine created successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to create the Azure Virtual Machine: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}