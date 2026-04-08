<#
.SYNOPSIS
    Create a new Azure Resource Group with the Azure PowerShell.

.DESCRIPTION
    This script creates a new Azure Resource Group with the Azure PowerShell.
    The script uses the following Azure PowerShell command:
    New-AzResourceGroup -Name $ResourceGroup -Location $Location

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Location
    Defines the location of the Azure Resource Group.

.PARAMETER Tags
    Defines the tags for the Azure Resource Group.

.EXAMPLE
    .\New-AzResourceGroup.ps1 -ResourceGroup "myResourceGroup" -Location "westus"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.Resources

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.resources/new-azresourcegroup?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Resources

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage = "The name of the Azure Resource Group to create.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the Resource Group will be created.")]
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

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name        = $ResourceGroup
    Location    = $Location
}

if ($Tags) {
    $parameters['Tag'] = $Tags
}

try {
    # Create the Resource Group
    New-AzResourceGroup @parameters

    # Output the result
    Write-Host "✅ Azure Resource Group '$($ResourceGroup)' created successfully in location '$($Location)'." -ForegroundColor Green

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1

} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
