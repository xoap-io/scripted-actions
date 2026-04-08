<#
.SYNOPSIS
    Create an Azure Image Builder Windows VM using Azure PowerShell commands.

.DESCRIPTION
    This script creates an Azure Image Builder Windows VM using Azure PowerShell commands. It registers necessary
    providers, creates a resource group, user-assigned identity, role definition, and image template,
    and finally creates a VM from the image.

    Uses Get-AzResourceProvider, Register-AzResourceProvider, New-AzResourceGroup,
    New-AzUserAssignedIdentity, New-AzRoleDefinition, New-AzRoleAssignment.

.PARAMETER AzResourceGroup
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

.EXAMPLE
    .\wip_az-ps-image-builder-windows.ps1 -AzResourceGroup "myResourceGroup" -AzLocation "westus2" -AzVmName "myWinVM01" -AzVmSize "Standard_D2s_v3"

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
    https://learn.microsoft.com/en-us/azure/virtual-machines/image-builder-overview

.COMPONENT
    Azure PowerShell Compute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzResourceGroup = "myResourceGroup",

    [Parameter(Mandatory = $true, HelpMessage = "Defines the location for the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzLocation = "westus2",

    [Parameter(Mandatory = $true, HelpMessage = "Defines the name of the Azure VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzVmName = "myWinVM01",

    [Parameter(Mandatory = $true, HelpMessage = "Defines the size of the Azure VM.")]
    [ValidateSet(
        'Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_D8s_v3',
        'Standard_D2s_v5', 'Standard_D4s_v5', 'Standard_D8s_v5',
        'Standard_E2s_v3', 'Standard_E4s_v3', 'Standard_E8s_v3'
    )]
    [string]$AzVmSize = "Standard_D2s_v3",

    [Parameter(Mandatory = $false, HelpMessage = "Increase logging verbosity to show all debug logs.")]
    [switch]$AzDebug,

    [Parameter(Mandatory = $false, HelpMessage = "Only show errors, suppressing warnings.")]
    [switch]$AzOnlyShowErrors,

    [Parameter(Mandatory = $false, HelpMessage = "Output format.")]
    [string]$AzOutput,

    [Parameter(Mandatory = $false, HelpMessage = "JMESPath query string.")]
    [string]$AzQuery,

    [Parameter(Mandatory = $false, HelpMessage = "Increase logging verbosity.")]
    [switch]$AzVerbose
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    ResourceGroup  = $AzResourceGroup
    Location       = $AzLocation
    VmName         = $AzVmName
    VmSize         = $AzVmSize
    Debug          = $AzDebug
    OnlyShowErrors = $AzOnlyShowErrors
    Output         = $AzOutput
    Query          = $AzQuery
    Verbose        = $AzVerbose
}

try {
    # Register necessary providers
    Get-AzResourceProvider -ProviderNamespace Microsoft.Compute, Microsoft.KeyVault, Microsoft.Storage, Microsoft.VirtualMachineImages, Microsoft.Network, Microsoft.ManagedIdentity | Where-Object RegistrationState -ne Registered | Register-AzResourceProvider

    # Create resource group
    New-AzResourceGroup -Name $parameters.ResourceGroup -Location $parameters.Location

    # Create user-assigned identity
    $identityName = "aibBuiUserId$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-AzUserAssignedIdentity -ResourceGroup $parameters.ResourceGroup -Name $identityName

    # Get identity ID and URI
    $imgBuilderCliId = (Get-AzUserAssignedIdentity -ResourceGroup $parameters.ResourceGroup -Name $identityName).ClientId
    $subscriptionID = (Get-AzContext).Subscription.Id
    $imgBuilderId = "/subscriptions/$subscriptionID/resourceGroups/$parameters.ResourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/$identityName"

    # Download and update role definition template
    $roleDefTemplate = "aibRoleImageCreation.json"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Azure/azvmimagebuilder/master/solutions/12_Creating_AIB_Security_Roles/aibRoleImageCreation.json" -OutFile $roleDefTemplate
    (Get-Content $roleDefTemplate) -replace '<subscriptionID>', $subscriptionID -replace '<rgName>', $parameters.ResourceGroup -replace 'Azure Image Builder Service Image Creation Role', "Azure Image Builder Image Def$(Get-Date -Format 'yyyyMMddHHmmss')" | Set-Content $roleDefTemplate

    # Create role definition and assign role
    New-AzRoleDefinition -InputFile $roleDefTemplate
    New-AzRoleAssignment -Assignee $imgBuilderCliId -RoleDefinitionName "Azure Image Builder Image Def$(Get-Date -Format 'yyyyMMddHHmmss')" -Scope "/subscriptions/$subscriptionID/resourceGroups/$parameters.ResourceGroup"

    # Download and update image template
    $imageTemplate = "helloImageTemplateWin.json"
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/azure/azvmimagebuilder/master/quickquickstarts/0_Creating_a_Custom_Windows_Managed_Image/helloImageTemplateWin.json" -OutFile $imageTemplate
    (Get-Content $imageTemplate) -replace '<subscriptionID>', $subscriptionID -replace '<rgName>', $parameters.ResourceGroup -replace '<region>', $parameters.Location -replace '<imageName>', 'aibWinImage' -replace '<runOutputName>', 'aibWindows' -replace '<imgBuilderId>', $imgBuilderId | Set-Content $imageTemplate

    # Create and run image template
    az resource create --resource-group $parameters.ResourceGroup --properties @$imageTemplate --is-full-object --resource-type Microsoft.VirtualMachineImages/imageTemplates -n helloImageTemplateWin01
    az resource invoke-action --resource-group $parameters.ResourceGroup --resource-type Microsoft.VirtualMachineImages/imageTemplates -n helloImageTemplateWin01 --action Run

    # Create VM from image
    az vm create --resource-group $parameters.ResourceGroup --name $parameters.VmName --admin-username aibuser --location $parameters.Location --image "/subscriptions/$subscriptionID/resourceGroups/$parameters.ResourceGroup/providers/Microsoft.Compute/galleries/myIbGallery/images/myIbImageDef/versions/latest" --security-type TrustedLaunch --generate-ssh-keys

    # Output the result
    Write-Host "✅ Azure Image Builder Windows VM created successfully." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
