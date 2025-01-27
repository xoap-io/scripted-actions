<#
.SYNOPSIS
    Create an Azure Linux VM.

.DESCRIPTION
    This script creates an Azure Linux VM. It registers necessary providers, creates a resource group, and creates a VM with the specified parameters.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER OpenPorts
    Defines the ports to open on the Azure Virtual Machine.

.PARAMETER VmSize
    Defines the size of the Azure Virtual Machine.

.EXAMPLE
    .\wip_az-cli-create-linux-vm.ps1 -AzResourceGroup "myResourceGroup" -AzOpenPorts "3389" -AzVmSize "Standard_A1_v2"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/vm
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = 'myResourceGroup',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzOpenPorts = '3389',

    [Parameter(Mandatory=$true)]
    [ValidateSet('Standard_A0', 'Standard_A1', 'Standard_A2', 'Standard_A3', 'Standard_A4', 'Standard_A5', 'Standard_A6', 'Standard_A7', 'Standard_A8', 'Standard_A9', 'Standard_A10', 'Standard_A11', 'Standard_A1_v2', 'Standard_A2_v2', 'Standard_A4_v2', 'Standard_A8_v2', 'Standard_A2m_v2', 'Standard_A4m_v2', 'Standard_A8m_v2', 'Standard_B1s', 'Standard_B1ms', 'Standard_B2s', 'Standard_B2ms', 'Standard_B4ms', 'Standard_B8ms', 'Standard_B12ms', 'Standard_B16ms', 'Standard_B20ms', 'Standard_B24ms', 'Standard_B1ls', 'Standard_B1s', 'Standard_B2s', 'Standard_B4s', 'Standard_B8s', 'Standard_B12s', 'Standard_B16s', 'Standard_B20s', 'Standard_B24s', 'Standard_D1', 'Standard_D2', 'Standard_D3', 'Standard_D4', 'Standard_D11', 'Standard_D12', 'Standard_D13', 'Standard_D14', 'Standard_D1_v2', 'Standard_D2_v2', 'Standard_D3_v2', 'Standard_D4_v2', 'Standard_D5_v2', 'Standard_D11_v2', 'Standard_D12_v2', 'Standard_D13_v2', 'Standard_D14_v2', 'Standard_D15_v2', 'Standard_D2_v3', 'Standard_D4_v3', 'Standard_D8_v3', 'Standard_D16_v3', 'Standard_D32_v3', 'Standard_D48_v3', 'Standard_D64_v3', 'Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_D8s_v3', 'Standard_D16s_v3', 'Standard_D32s_v3', 'Standard_D48s_v3', 'Standard_D64s_v3', 'Standard_D2_v4', 'Standard_D4_v4', 'Standard_D8_v4', 'Standard_D16_v4', 'Standard_D32_v4', 'Standard_D48_v4', 'Standard_D64_v4', 'Standard_D2s_v4')]
    [string]$AzVmSize
)

# Splatting parameters for better readability
$parameters = @{
    resource_group   = $AzResourceGroup
    open_ports       = $AzOpenPorts
    vm_size          = $AzVmSize
    debug            = $AzDebug
    only_show_errors = $AzOnlyShowErrors
    output           = $AzOutput
    query            = $AzQuery
    verbose          = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Register necessary providers
    az provider register -n Microsoft.VirtualMachineImages
    az provider register -n Microsoft.Compute
    az provider register -n Microsoft.KeyVault
    az provider register -n Microsoft.Storage
    az provider register -n Microsoft.Network
    az provider register -n Microsoft.ContainerInstance

    # Create resource group
    az group create -n $parameters.resource_group -l westus2

    # Create VM
    az vm create `
        --resource-group $parameters.resource_group `
        --name myLinuxVM `
        --image UbuntuLTS `
        --admin-username azureuser `
        --size $parameters.vm_size `
        --generate-ssh-keys `
        --public-ip-sku Standard

    # Open specified ports
    az vm open-port `
        --resource-group $parameters.resource_group `
        --name myLinuxVM `
        --port $parameters.open_ports

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