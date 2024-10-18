<#
.SYNOPSIS
    Create an Azure Virtual Desktop Application Group with the Azure CLI.

.DESCRIPTION
    This script creates an Azure Virtual Desktop Application Group with the Azure CLI.
    The script uses the following Azure CLI command:
    az desktopvirtualization applicationgroup create --resource-group $AzResourceGroup --name $AzAppGroupName --location $AzLocation --host-pool-arm-path $AzHostPoolArmPath --application-group-type $AzAppGroupType

.PARAMETER AppGroupType
    Defines the type of the Azure Virtual Desktop Application Group.

.PARAMETER HostPoolArmPath
    Defines the ARM path of the Azure Virtual Desktop Host Pool.

.PARAMETER Name
    Defines the name of the Azure Virtual Desktop Application Group.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Description
    Defines the description of the Azure Virtual Desktop Application Group.

.PARAMETER FriendlyName
    Defines the friendly name of the Azure Virtual Desktop Application Group.

.PARAMETER Location
    Defines the location of the Azure Virtual Desktop Application Group.

.PARAMETER Tags
    Defines the tags for the Azure Virtual Desktop Application Group.

.EXAMPLE
    .\az-cli-avd-applicationgroup-create.ps1 -AzResourceGroup "MyResourceGroup" -AzAppGroupName "MyAppGroup" -AzLocation "eastus" -AzHostPoolArmPath "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/myResourceGroup/providers/Microsoft.DesktopVirtualization/hostPools/myHostPool" -AzAppGroupType "RemoteApp"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup

.LINK
    https://learn.microsoft.com/en-us/cli/azure/desktopvirtualization/applicationgroup?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Desktop',
        'RemoteApp'
    )]
    [string]$AppGroupType,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolArmPath,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
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
    [string]$Tags
)

# Splatting parameters for better readability
$parameters = `
    '--application-group-type', $AppGroupType 
    '--resource-group', $ResourceGroup
    '--name', $AppGroupName 
    '--host-pool-arm-path', $HostPoolArmPath

if ($Description) {
    $parameters += '--description', $Description
}

if ($FriendlyName) {
    $parameters += '--friendly-name', $FriendlyName
}

if ($Tags) {
    $parameters += '--tags', $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the Azure Virtual Desktop Application Group
    az desktopvirtualization applicationgroup create @parameters

    # Output the result
    Write-Output "Azure Virtual Desktop Application Group created successfully."

} catch {
    # Log the error to the console
    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Virtual Desktop Application Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
