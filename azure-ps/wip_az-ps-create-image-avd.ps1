<#
.SYNOPSIS
    Create an Azure Image Builder Windows VM image for AVD using Azure CLI commands.

.DESCRIPTION
    This script creates an Azure Image Builder Windows VM using Azure CLI commands. It registers necessary
    providers, creates a resource group, user-assigned identity, role definition, and image template,
    and finally creates a VM from the image.

    Uses az provider register, az group create, az identity create, az role definition create,
    az role assignment create, az resource create, az resource invoke-action, az vm create.

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzOpenPorts
    Defines the ports to be opened on the VM.

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
    .\wip_az-ps-create-image-avd.ps1 -AzResourceGroup "myResourceGroup" -AzOpenPorts "3389" -AzVmSize "Standard_D2s_v3"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Azure CLI (az)

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

    [Parameter(Mandatory = $true, HelpMessage = "Defines the ports to be opened on the VM.")]
    [ValidateNotNullOrEmpty()]
    [string]$AzOpenPorts = '3389',

    [Parameter(Mandatory = $true, HelpMessage = "Defines the size of the Azure VM.")]
    [ValidateSet(
        'Standard_D2s_v3', 'Standard_D4s_v3', 'Standard_D8s_v3',
        'Standard_D2s_v5', 'Standard_D4s_v5', 'Standard_D8s_v5',
        'Standard_E2s_v3', 'Standard_E4s_v3', 'Standard_E8s_v3'
    )]
    [string]$AzVmSize,

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
    resource_group   = $AzResourceGroup
    open_ports       = $AzOpenPorts
    vm_size          = $AzVmSize
    debug            = $AzDebug
    only_show_errors = $AzOnlyShowErrors
    output           = $AzOutput
    query            = $AzQuery
    verbose          = $AzVerbose
}

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
    Write-Host "✅ Azure Image Builder Windows VM created successfully." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
