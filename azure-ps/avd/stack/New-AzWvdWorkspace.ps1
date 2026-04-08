<#
.SYNOPSIS
    Creates a new workspace in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new workspace in an Azure Virtual Desktop environment with the specified parameters.
    Uses the New-AzWvdWorkspace cmdlet from the Az.DesktopVirtualization module.

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
    The SKU name of the workspace.

.PARAMETER SkuSize
    The SKU size of the workspace.

.PARAMETER SkuTier
    The SKU tier of the workspace.

.PARAMETER Tags
    The tags for the workspace.

.EXAMPLE
    PS C:\> .\New-AzWvdWorkspace.ps1 -Name "MyWorkspace" -ResourceGroup "MyResourceGroup" -Location "eastus"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdworkspace?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$false, HelpMessage = "References to application groups to include in the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$ApplicationGroupReference,

    [Parameter(Mandatory=$false, HelpMessage = "Description of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "Friendly display name of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[ResourcstringeIdentityType]$IdentityType,

    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[string]$Kind,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the workspace will be created.")]
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

    [Parameter(Mandatory=$false, HelpMessage = "The managed by property of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$ManagedBy,

    [Parameter(Mandatory=$false, HelpMessage = "The plan name of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanName,

    [Parameter(Mandatory=$false, HelpMessage = "The plan product of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanProduct,

    [Parameter(Mandatory=$false, HelpMessage = "The plan promotion code of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPromotionCode,

    [Parameter(Mandatory=$false, HelpMessage = "The plan publisher of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPublisher,

    [Parameter(Mandatory=$false, HelpMessage = "The plan version of the workspace.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanVersion,

    [Parameter(Mandatory=$false, HelpMessage = "Public network access setting (Enabled or Disabled).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Enabled',
        'Disabled'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU capacity.")]
    [ValidateNotNullOrEmpty()]
    [int]$SkuCapacity,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU family.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuFamily,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU name.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuName,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU size.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuSize,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU tier.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuTier,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the workspace.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

# Splatting parameters for better readability
$parameters = @{
    Name              = $Name
    ResourceGroupName = $ResourceGroup
    Location          = $Location
}

if ($ApplicationGroupReference) {
    $parameters['ApplicationGroupReference'] = $ApplicationGroupReference
}

if ($Description) {
    $parameters['Description'] = $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'] = $FriendlyName
}

if ($ManagedBy) {
    $parameters['ManagedBy'] = $ManagedBy
}

if ($PlanName) {
    $parameters['PlanName'] = $PlanName
}

if ($PlanProduct) {
    $parameters['PlanProduct'] = $PlanProduct
}

if ($PlanPromotionCode) {
    $parameters['PlanPromotionCode'] = $PlanPromotionCode
}

if ($PlanPublisher) {
    $parameters['PlanPublisher'] = $PlanPublisher
}

if ($PlanVersion) {
    $parameters['PlanVersion'] = $PlanVersion
}

if ($PublicNetworkAccess) {
    $parameters['PublicNetworkAccess'] = $PublicNetworkAccess
}

if ($SkuCapacity) {
    $parameters['SkuCapacity'] = $SkuCapacity
}

if ($SkuFamily) {
    $parameters['SkuFamily'] = $SkuFamily
}

if ($SkuName) {
    $parameters['SkuName'] = $SkuName
}

if ($SkuSize) {
    $parameters['SkuSize'] = $SkuSize
}

if ($SkuTier) {
    $parameters['SkuTier'] = $SkuTier
}

if ($Tags) {
    $parameters['Tag'] = $Tags
}

try {
    # Create the workspace and capture the result
    $result = New-AzWvdWorkspace @parameters

    # Output the result
    Write-Host "✅ Workspace created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
