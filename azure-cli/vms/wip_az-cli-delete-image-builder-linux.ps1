<#
.SYNOPSIS
    Short description

.DESCRIPTION
    Long description

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT


.LINK
    https://github.com/scriptrunner/ActionPacks/tree/master/ActiveDirectory/Users

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$AZOpenPorts = '3389',
    [Parameter(Mandatory)]
    [string]$AzVmSize
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

az resource delete `
    --resource-group $sigResourceGroup `
    --resource-type Microsoft.VirtualMachineImages/imageTemplates `
    -n helloImageTemplateforSIG01

az role assignment delete `
    --assignee $imgBuilderCliId `
    --role "$imageRoleDefName" `
    --scope /subscriptions/$subscriptionID/resourceGroups/$sigResourceGroup

az role definition delete --name "$imageRoleDefName"

az identity delete --ids $imgBuilderId

sigDefImgVersion=$(az sig image-version list `
	-g $sigResourceGroup `
	--gallery-name $sigName `
	--gallery-image-definition $imageDefName `
	--subscription $subscriptionID --query [].'name' -o json | grep 0. | tr -d '"')
	az sig image-version delete `
	-g $sigResourceGroup `
	--gallery-image-version $sigDefImgVersion `
	--gallery-name $sigName `
	--gallery-image-definition $imageDefName `
	--subscription $subscriptionID

az sig image-definition delete `
	-g $sigResourceGroup `
	--gallery-name $sigName `
	--gallery-image-definition $imageDefName `
	--subscription $subscriptionID

az sig delete -r $sigName -g $sigResourceGroup

az group delete -n $sigResourceGroup -y
