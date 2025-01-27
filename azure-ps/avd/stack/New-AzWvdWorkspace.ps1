<#
.SYNOPSIS
    Creates a new workspace in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new workspace in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER Name
    The name of the workspace.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER ApplicationGroupReference
    References to application groups.

.PARAMETER Description
    The description of the workspace.

.PARAMETER FriendlyName
    The friendly name of the workspace.

.PARAMETER IdentityType
    The identity type of the workspace.

.PARAMETER Kind
    The kind of the workspace.

.PARAMETER Location
    The location of the workspace.

.PARAMETER ManagedBy
    The managed by property of the workspace.

.PARAMETER PlanName
    The plan name of the workspace.

.PARAMETER PlanProduct
    The plan product of the workspace.

.PARAMETER PlanPromotionCode
    The plan promotion code of the workspace.

.PARAMETER PlanPublisher
    The plan publisher of the workspace.

.PARAMETER PlanVersion
    The plan version of the workspace.

.PARAMETER PublicNetworkAccess
    The public network access of the workspace.

.PARAMETER SkuCapacity
    The SKU capacity of the workspace.

.PARAMETER SkuFamily
    The SKU family of the workspace.

.PARAMETER SkuName
T   he SKU name of the workspace.

.PARAMETER SkuSize
    The SKU size of the workspace.

.PARAMETER SkuTier
    The SKU tier of the workspace.

.PARAMETER Tags
    The tags for the workspace.

.EXAMPLE
    PS C:\> .\New-AzWvdWorkspace.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup" -Location "East US"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdworkspace?view=azps-12.3.0

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure PowerShell

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupReference,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[ResourcstringeIdentityType]$IdentityType,

    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[string]$Kind,

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
        'canada', 'europe', 'france', 'germany',
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
    [string]$PlanName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanProduct,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPromotionCode,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPublisher,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanVersion,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Enabled',
        'Disabled'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$SkuCapacity,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuFamily,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuSize,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$SkuTier,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroup = $ResourceGroup
    Location          = $Location
}

if ($ApplicationGroupReference) {
    $parameters['ApplicationGroupReference'], $ApplicationGroupReference
}

if ($Description) {
    $parameters['Description'], $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'], $FriendlyName
}

if ($IdentityType) {
    $parameters['IdentityType'], $IdentityType
}

if ($ManagedBy) {
    $parameters['ManagedBy'], $ManagedBy
}

if ($PlanName) {
    $parameters['PlanName'], $PlanName
}

if ($PlanProduct) {
    $parameters['PlanProduct'], $PlanProduct
}

if ($PlanPromotionCode) {
    $parameters['PlanPromotionCode'], $PlanPromotionCode
}

if ($PlanPublisher) {
    $parameters['PlanPublisher'], $PlanPublisher
}

if ($PlanVersion) {
    $parameters['PlanVersion'], $PlanVersion
}

if ($PublicNetworkAccess) {
    $parameters['PublicNetworkAccess'], $PublicNetworkAccess
}

if ($SkuCapacity) {
    $parameters['SkuCapacity'], $SkuCapacity
}

if ($SkuFamily) {
    $parameters['SkuFamily'], $SkuFamily
}

if ($SkuName) {
    $parameters['SkuName'], $SkuName
}

if ($SkuSize) {
    $parameters['SkuSize'], $SkuSize
}

if ($SkuTier) {
    $parameters['SkuTier'], $SkuTier
}

if ($Tags) {
    $parameters['Tag'], $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop" 

try {
    # Create the workspace and capture the result
    $result = New-AzWvdWorkspace @parameters

    # Output the result
    Write-Output "Workspace created successfully:"
    Write-Output $result

} catch [System.Exception] {
    # Log the error to the console

    Write-Output "Error message $errorMessage"


    Write-Error "Failed to create the workspace: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
