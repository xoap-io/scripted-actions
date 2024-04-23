<#
.SYNOPSIS
    This script deploys a Bicep template to Azure using Azure PowerShell.

.DESCRIPTION
    This script deploys a Bicep template to Azure using Azure PowerShell. The script requires the following parameters:
    - AzResourceGroupName: Defines the name of the Azure Resource Group.
    - BicepTemplateFile: Defines the path to the Bicep template file.
    - BicepTemplateParameterFile: Defines the path to the Bicep template parameter file.

    The script will deploy the Bicep template to Azure with the provided parameters.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    Azure PowerShell

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER BicepTemplateFile
    Defines the path to the Bicep template file.

.PARAMETER BicepTemplateParameterFile
    Defines the path to the Bicep template parameter file.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName = "myResourceGroup",
    [Parameter(Mandatory)]
    [string]$BicepTemplateFile = "myBicepTemplate.bicep",
    [Parameter(Mandatory)]
    [string]$BicepTemplateParameterFile = "myBicepTemplateParameters.json"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

New-AzResourceGroupDeployment `
	-ResourceGroupName $AzResourceGroupName `
    -TemplateFile $BicepTemplateFile `
	-TemplateParameterFile $BicepTemplateParameterFile
