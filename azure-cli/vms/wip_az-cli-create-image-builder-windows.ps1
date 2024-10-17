<#
.SYNOPSIS
    Create an Azure Image Builder Windows VM.

.DESCRIPTION
    This script creates an Azure Image Builder Windows VM. It registers necessary providers, creates a resource group, user-assigned identity, role definitions, and assigns roles. It also creates an image template and finally creates a VM from the image.

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzOpenPorts
    Defines the ports to open on the Azure Virtual Machine.

.PARAMETER AzVmSize
    Defines the size of the Azure Virtual Machine.

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
    .\wip_az-cli-create-image-builder-windows.ps1 -AzResourceGroupName "myResourceGroup" -AzOpenPorts "3389" -AzVmSize "Standard_A1_v2"

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
    [string]$AzResourceGroupName = 'myResourceGroup',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzOpenPorts = '3389',

    [Parameter(Mandatory=$true)]
    [ValidateSet('Standard_A0', 'Standard_A1', 'Standard_A2', 'Standard_A3', 'Standard_A4', 'Standard_A5', 'Standard_A6', 'Standard_A7', 'Standard_A8', 'Standard_A9', 'Standard_A10', 'Standard_A11', 'Standard_A1_v2', 'Standard_A2_v2', 'Standard_A4_v2', 'Standard_A8_v2', 'Standard_A2m_v2', 'Standard_A4m_v2', 'Standard_A8m_v2', 'Standard_B1s', 'Standard_B1ms', 'Standard_B2s', 'Standard_B2ms', 'Standard_B4ms', 'Standard_B8ms', 'Standard_B12ms', 'Standard_B16ms', 'Standard_B20ms', 'Standard_B24ms', 'Standard_B1ls', 'Standard_B1s', 'Standard_B2s', 'Standard_B4s', 'Standard_B8s', 'Standard_B12s', 'Standard_B16s', 'Standard_B20s', 'Standard_B24s', 'Standard_D1', 'Standard_D2', 'Standard_D3', 'Standard_D4', 'Standard_D11', 'Standard_D12', 'Standard_D13', 'Standard_D14', 'Standard_D1_v2', 'Standard_D2_v2', 'Standard_D3_v2', 'Standard_D4_v2', 'Standard_D5_v2', 'Standard_D11_v2', 'Standard_D12_v2', 'Standard_D13_v2', 'Standard_D14_v2', 'Standard_D15_v2', 'Standard_D2_v3', 'Standard_D4_v3', 'Standard_D8_v3', 'Standard_D16_v3', 'Standard_D32_v3', 'Standard_D48_v3', 'Standard_D64_v3', 'Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_D8s_v3', 'Standard_D16s_v3', 'Standard_D32s_v3', 'Standard_D48s_v3', 'Standard_D64s_v3', 'Standard_D2_v4', 'Standard_D4_v4', 'Standard_D8_v4', 'Standard_D16_v4', 'Standard_D32_v4', 'Standard_D48_v4', 'Standard_D64_v4', 'Standard_D2s_v4')]
    [string]$AzVmSize,

    [Parameter(Mandatory=$false)]
    [switch]$AzDebug,

    [Parameter(Mandatory=$false)]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory=$false)]
    [string]$AzOutput,

    [Parameter(Mandatory=$false)]
    [string]$AzQuery,

    [Parameter(Mandatory=$false)]
    [switch]$AzVerbose,


)

# Splatting parameters for better readability
$parameters = @{
    resource_group   = $AzResourceGroupName
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

    # Create user-assigned identity
    $identityName = "aibBuiUserId$(Get-Date -Format 'yyyyMMddHHmmss')"
    az identity create -g $parameters.resource_group -n $identityName

    # Get identity ID and URI
    $imgBuilderCliId = az identity show -g $parameters.resource_group -n $identityName --query clientId -o tsv
    $subscriptionID = az account show --query id --output tsv
    $imgBuilderId = "/subscriptions/$subscriptionID/resourcegroups/$parameters.resource_group/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName"

    # Download and update role definition template
    $roleDefTemplate = "aibRoleImageCreation.json"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json" -OutFile $roleDefTemplate
    (Get-Content $roleDefTemplate) -replace '<subscriptionID>', $subscriptionID -replace '<rgName>', $parameters.resource_group -replace 'Azure Image Builder Service Image Creation Role', "Azure Image Builder Image Def$(Get-Date -Format 'yyyyMMddHHmmss')" | Set-Content $roleDefTemplate

    # Create role definition and assign role
    az role definition create --role-definition ./$roleDefTemplate
    az role assignment create --assignee $imgBuilderCliId --role "Azure Image Builder Image Def$(Get-Date -Format 'yyyyMMddHHmmss')" --scope "/subscriptions/$subscriptionID/resourceGroups/$parameters.resource_group"

    # Download and update image template
    $imageTemplate = "helloImageTemplateWin.json"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/azure/azvmimagebuilder/master/quickquickstarts/0_Creating_a_Custom_Windows_Managed_Image/helloImageTemplateWin.json" -OutFile $imageTemplate
    (Get-Content $imageTemplate) -replace '<subscriptionID>', $subscriptionID -replace '<rgName>', $parameters.resource_group -replace '<region>', 'westus2' -replace '<imageName>', 'aibWinImage' -replace '<runOutputName>', 'aibWindows' -replace '<imgBuilderId>', $imgBuilderId | Set-Content $imageTemplate

    # Create and run image template
    az resource create --resource-group $parameters.resource_group --properties @$imageTemplate --is-full-object --resource-type Microsoft.VirtualMachineImages/imageTemplates -n helloImageTemplateWin01
    az resource invoke-action --resource-group $parameters.resource_group --resource-type Microsoft.VirtualMachineImages/imageTemplates -n helloImageTemplateWin01 --action Run

    # Create VM from image
    az vm create --resource-group $parameters.resource_group --name myAibGalleryVM --admin-username aibuser --location westus2 --image "/subscriptions/$subscriptionID/resourceGroups/$parameters.resource_group/providers/Microsoft.Compute/galleries/myIbGallery/images/myIbImageDef/versions/latest" --security-type TrustedLaunch --generate-ssh-keys

    # Output the result
    Write-Output "Azure Image Builder Windows VM created successfully."
} catch {
    # Log the error to the console

Write-Output "Error message $errorMessage"


    Write-Error "Failed to create Azure Image Builder Windows VM: $($_.Exception.Message)"
} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}