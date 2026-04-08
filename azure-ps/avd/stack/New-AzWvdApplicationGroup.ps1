<#
.SYNOPSIS
    Creates a new application group in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new application group in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER Name
The name of the application group.

.PARAMETER ResourceGroup
    The name of the resource group.

.PARAMETER ApplicationGroupType
    The type of the application group.

.PARAMETER HostPoolArmPath
    The ARM path of the host pool.

.PARAMETER Description
    The description of the application group.

.PARAMETER FriendlyName
    The friendly name of the application group.

.PARAMETER IdentityType
    The identity type of the application group.

.PARAMETER Kind
    The kind of the application group.

.PARAMETER Location
    The location of the application group.

.PARAMETER ManagedBy
    The managed by property of the application group.

.PARAMETER PlanName
    The plan name of the application group.

.PARAMETER PlanProduct
    The plan product of the application group.

.PARAMETER PlanPromotionCode
    The plan promotion code of the application group.

.PARAMETER PlanPublisher
    The plan publisher of the application group.

.PARAMETER PlanVersion
    The plan version of the application group.

.PARAMETER ShowInFeed
    Indicates if the application group should be shown in the feed.

.PARAMETER SkuCapacity
    The SKU capacity of the application group.

.PARAMETER SkuFamily
    The SKU family of the application group.

.PARAMETER SkuName
    The SKU name of the application group.

.PARAMETER SkuSize
    The SKU size of the application group.

.PARAMETER SkuTier
    The SKU tier of the application group.

.PARAMETER Tags
    The tags for the application group.

.EXAMPLE
    PS C:\> .\New-AzWvdApplicationGroup.ps1 -Name "MyAppGroup" -ResourceGroup "MyResourceGroup" -ApplicationGroupType "RemoteApp" -HostPoolArmPath "/subscriptions/xxxx/resourceGroups/xxxx/providers/Microsoft.DesktopVirtualization/hostPools/xxxx"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdapplicationgroup?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The type of the application group (RemoteApp or Desktop).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('RemoteApp', 'Desktop')]
    [string]$ApplicationGroupType,

    [Parameter(Mandatory=$true, HelpMessage = "The ARM path of the host pool.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolArmPath,

    [Parameter(Mandatory=$false, HelpMessage = "Description of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "Friendly display name of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false, HelpMessage = "The identity type of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$IdentityType,

    [Parameter(Mandatory=$false, HelpMessage = "The kind of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$Kind,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the application group will be created.")]
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

    [Parameter(Mandatory=$false, HelpMessage = "The managed by property of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ManagedBy,

    [Parameter(Mandatory=$false, HelpMessage = "The plan name of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanName,

    [Parameter(Mandatory=$false, HelpMessage = "The plan product of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanProduct,

    [Parameter(Mandatory=$false, HelpMessage = "The plan promotion code of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPromotionCode,

    [Parameter(Mandatory=$false, HelpMessage = "The plan publisher of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPublisher,

    [Parameter(Mandatory=$false, HelpMessage = "The plan version of the application group.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanVersion,

    [Parameter(Mandatory=$false, HelpMessage = "Show this application group in the feed.")]
    [ValidateNotNullOrEmpty()]
    [switch]$ShowInFeed,

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

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the application group.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Splatting parameters for better readability
$parameters = @{
    Name = $Name
    ResourceGroupName = $ResourceGroup
    ApplicationGroupType = $ApplicationGroupType
    HostPoolArmPath = $HostPoolArmPath
    Location = $Location
}

if ($Description) {
    $parameters['Description'] = $Description
}

if ($FriendlyName) {
    $parameters['FriendlyName'] = $FriendlyName
}

if ($IdentityType) {
    $parameters['IdentityType'] = $IdentityType
}

if ($Kind) {
    $parameters['Kind'] = $Kind
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

if ($ShowInFeed) {
    $parameters['ShowInFeed'] = $ShowInFeed
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

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create the application group and capture the result
    $result = New-AzWvdApplicationGroup @parameters

    # Output the result
    Write-Host "✅ Application group created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
