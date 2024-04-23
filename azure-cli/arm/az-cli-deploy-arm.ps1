<#
.SYNOPSIS
    Deploy an ARM template to an Azure Resource Group.

.DESCRIPTION
    This script deploys an ARM template to an Azure Resource Group.

    The script uses the Azure CLI to deploy the ARM template to the specified Azure Resource Group.

    The script uses the following Azure CLI command:
    az deployment group create `
        --resource-group $AzResourceGroupName `
        --template-file $ArmTemplateFile `
        --parameters $ArmTemplateParametersFile

    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    Azure CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AzResourceGroupName
    Defines the name of the Azure Resource Group.

.PARAMETER ArmTemplateFile
    Defines the path to the ARM template file.

.PARAMETER ArmTemplateParametersFile
    Defines the path to the ARM template parameters file.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AzResourceGroupName,
    [Parameter(Mandatory)]
    [string]$ArmTemplateFile,
    [Parameter(Mandatory)]
    [string]$ArmTemplateParametersFile
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

# Deploy template into resource group
az deployment group create `
    --resource-group $AzResourceGroupName `
	--template-file $ArmTemplateFile `
	--parameters $ArmTemplateParametersFile
