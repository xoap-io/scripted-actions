<#
.SYNOPSIS
    Create a new Azure Resource Group with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure Resource Group with the Azure PowerShell.
    The script uses the following Azure PowerShell command:
    New-AzResourceGroup -Name $AzResourceGroup -Location $AzLocation

.PARAMETER AzResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER AzLocation
    Defines the location of the Azure Resource Group.

.PARAMETER Tags
    Defines the tags for the Azure Resource Group.

.EXAMPLE
    .\New-AzResourceGroup.ps1 -AzResourceGroup "myResourceGroup" -AzLocation "westus"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.Resources

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.resources/new-azresourcegroup?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

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
    [hashtable]$Tags
)

# Splatting parameters for better readability
$parameters = @{
    Name        = $ResourceGroup
    Location    = $Location
}

if ($Tags) {
    $parameters['Tag'], $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the Resource Group
    New-AzResourceGroup @parameters

    # Output the result
    Write-Output "Azure Resource Group '$($ResourceGroup)' created successfully in location '$($Location)'."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"


    Write-Error "Failed to create Azure Resource Group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
