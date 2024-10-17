<#
.SYNOPSIS
    This script creates an Azure Image Builder Windows VM.

.DESCRIPTION
    This script creates an Azure Image Builder Windows VM using Azure PowerShell commands. It registers necessary providers, creates a resource group, user-assigned identity, role definition, and image template, and finally creates a VM from the image.

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER AzLocation
    Defines the location for the resource group.

.PARAMETER AzVmName
    Defines the name of the Azure VM.

.PARAMETER AzVmSize
    Defines the size of the Azure VM.

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
    .\wip_az-ps-image-builder-windows.ps1 -AzResourceGroupName "myResourceGroup" -AzLocation "westus2" -AzVmName "myWinVM01" -AzVmSize "Standard_D2s_v3"

.NOTES
    Ensure that Azure PowerShell is installed and authenticated before running the script.
    Author: Your Name
    Date:   2024-09-03
    Version: 1.1
    Requires: Azure PowerShell

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroupName = "myResourceGroup",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzLocation = "westus2",

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = "myWinVM01",

    [Parameter(Mandatory=$true)]
    [ValidateSet('Standard_A0', 'Standard_A1', 'Standard_A2', 'Standard_A3', 'Standard_A4', 'Standard_A5', 'Standard_A6', 'Standard_A7', 'Standard_A8', 'Standard_A9', 'Standard_A10', 'Standard_A11', 'Standard_A1_v2', 'Standard_A2_v2', 'Standard_A4_v2', 'Standard_A8_v2', 'Standard_A2m_v2', 'Standard_A4m_v2', 'Standard_A8m_v2', 'Standard_B1s', 'Standard_B1ms', 'Standard_B2s', 'Standard_B2ms', 'Standard_B4ms', 'Standard_B8ms', 'Standard_B12ms', 'Standard_B16ms', 'Standard_B20ms', 'Standard_B24ms', 'Standard_B1ls', 'Standard_B1s', 'Standard_B2s', 'Standard_B4s', 'Standard_B8s', 'Standard_B12s', 'Standard_B16s', 'Standard_B20s', 'Standard_B24s', 'Standard_D1', 'Standard_D2', 'Standard_D3', 'Standard_D4', 'Standard_D11', 'Standard_D12', 'Standard_D13', 'Standard_D14', 'Standard_D1_v2', 'Standard_D2_v2', 'Standard_D3_v2', 'Standard_D4_v2', 'Standard_D5_v2', 'Standard_D11_v2', 'Standard_D12_v2', 'Standard_D13_v2', 'Standard_D14_v2', 'Standard_D15_v2', 'Standard_D2_v3', 'Standard_D4_v3', 'Standard_D8_v3', 'Standard_D16_v3', 'Standard_D32_v3', 'Standard_D48_v3', 'Standard_D64_v3', 'Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_D8s_v3', 'Standard_D16s_v3', 'Standard_D32s_v3', 'Standard_D48s_v3', 'Standard_D64s_v3', 'Standard_D2_v4', 'Standard_D4_v4', 'Standard_D8_v4', 'Standard_D16_v4', 'Standard_D32_v4', 'Standard_D48_v4', 'Standard_D64_v4', 'Standard_D2s_v4')]
    [string]$AzVmSize = "Standard_D2s_v3",

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
    ResourceGroupName    = $AzResourceGroupName
    Location             = $AzLocation
    VmName               = $AzVmName
    VmSize               = $AzVmSize
    Debug                = $AzDebug
    OnlyShowErrors       = $AzOnlyShowErrors
    Output               = $AzOutput
    Query                = $AzQuery
    Verbose              = $AzVerbose
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Register necessary providers
    Get-AzResourceProvider -ProviderNamespace Microsoft.Compute, Microsoft.KeyVault, Microsoft.Storage, Microsoft.VirtualMachineImages, Microsoft.Network, Microsoft.ManagedIdentity | Where-Object RegistrationState -ne Registered | Register-AzResourceProvider

    # Create resource group
    New-AzResourceGroup -Name $parameters.ResourceGroupName -Location $parameters.Location

    # Create user-assigned identity
    $identityName = "aibBuiUserId$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-AzUserAssignedIdentity -ResourceGroupName $parameters.ResourceGroupName -Name $identityName

    # Get identity ID and URI
    $imgBuilderCliId = (Get-AzUserAssignedIdentity -ResourceGroupName $parameters.ResourceGroupName -Name $identityName).ClientId
    $subscriptionID = (Get-AzContext).Subscription.Id
    $imgBuilderId = "/subscriptions/$subscriptionID/resourceGroups/$parameters.ResourceGroupName/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName"

    # Download and update role definition template
    $roleDefTemplate = "aibRoleImageCreation.json"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json" -OutFile $roleDefTemplate
    (Get-Content $roleDefTemplate) -replace '<subscriptionID>', $subscriptionID -replace '<rgName>', $parameters.ResourceGroupName -replace 'Azure Image Builder Service Image Creation Role', "Azure Image Builder Image Def$(Get-Date -Format 'yyyyMMddHHmmss')" | Set-Content $roleDefTemplate

    # Create role definition and assign role
    New-AzRoleDefinition -InputFile $roleDefTemplate
    New-AzRoleAssignment -Assignee $imgBuilderCliId -RoleDefinitionName "Azure Image Builder Image Def$(Get-Date -Format 'yyyyMMddHHmmss')" -Scope "/subscriptions/$subscriptionID/resourceGroups/$parameters.ResourceGroupName"

    # Download and update image template
    $imageTemplate = "helloImageTemplateWin.json"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/azure/azvmimagebuilder/master/quickquickstarts/0_Creating_a_Custom_Windows_Managed_Image/helloImageTemplateWin.json" -OutFile $imageTemplate
    (Get-Content $imageTemplate) -replace '<subscriptionID>', $subscriptionID -replace '<rgName>', $parameters.ResourceGroupName -replace '<region>', $parameters.Location -replace '<imageName>', 'aibWinImage' -replace '<runOutputName>', 'aibWindows' -replace '<imgBuilderId>', $imgBuilderId | Set-Content $imageTemplate

    # Create and run image template
    az resource create --resource-group $parameters.ResourceGroupName --properties @$imageTemplate --is-full-object --resource-type Microsoft.VirtualMachineImages/imageTemplates -n helloImageTemplateWin01
    az resource invoke-action --resource-group $parameters.ResourceGroupName --resource-type Microsoft.VirtualMachineImages/imageTemplates -n helloImageTemplateWin01 --action Run

    # Create VM from image
    az vm create --resource-group $parameters.ResourceGroupName --name $parameters.VmName --admin-username aibuser --location $parameters.Location --image "/subscriptions/$subscriptionID/resourceGroups/$parameters.ResourceGroupName/providers/Microsoft.Compute/galleries/myIbGallery/images/myIbImageDef/versions/latest" --security-type TrustedLaunch --generate-ssh-keys

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