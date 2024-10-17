<#
.SYNOPSIS
    Create a new Azure Resource Group with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Resource Group with the Azure CLI.
    The script uses the following Azure CLI command:
    az group create --name $AzResourceGroupName --location $AzLocation

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Location
    Defines the location of the Azure Resource Group.

.PARAMETER ManagedBy
    Defines the managed by value of the Azure Resource Group.

.PARAMETER Tags
    Defines the tags for the Azure Resource Group.

.EXAMPLE
    .\az-cli-create-resource-group.ps1 -AzResourceGroupName "MyResourceGroup" -AzLocation "eastus"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/group

.LINK
    https://learn.microsoft.com/en-us/cli/azure/group?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'eastus', 'eastus2', 'southcentralus', 'westus2',
        'westus3', 'australiaeast', 'southeastasia', 'northeurope',
        'swedencentral', 'uksouth', 'westeurope', 'centralus',
        'southafricanorth', 'centralindia', 'eastasia', 'japaneast',
        'koreacentral', 'canadacentral', 'francecentral', 'germanywestcentral',
        'italynorth', 'norwayeast', 'polandcentral', 'switzerlandnorth',
        'uaenorth', 'brazilsouth', 'israelcentral', 'qatarcentral',
        'asia', 'asiapacific', 'australia', 'brazil',
        'canada', 'europe', 'france',
        'global', 'india', 'japan', 'korea',
        'norway', 'singapore', 'southafrica', 'sweden',
        'switzerland', 'unitedstates', 'northcentralus', 'westus',
        'japanwest', 'centraluseuap', 'eastus2euap', 'westcentralus',
        'southafricawest', 'australiacentral', 'australiacentral2', 'australiasoutheast',
        'koreasouth', 'southindia', 'westindia', 'canadaeast',
        'francesouth', 'germanynorth', 'norwaywest', 'switzerlandwest',
        'ukwest', 'uaecentral', 'brazilsoutheast'
    )]
    [string]$Location,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ManagedBy,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

# Splatting parameters for better readability
$parameters = `
    '--location', $Location ,`
    '--resource-group', $ResourceGroup

if ($ManagedBy) {
    $parameters += '--managed-by', $ManagedBy
}

if ($Tags) {
    $parameters += '--tags', $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create a new Azure Resource Group
    az group create @parameters

    # Output the result
    Write-Output "Azure Resource Group created successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Resource Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
