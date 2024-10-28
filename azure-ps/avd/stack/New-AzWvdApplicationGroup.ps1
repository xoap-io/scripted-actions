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

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.DesktopVirtualization

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdapplicationgroup?view=azps-12.3.0

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

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet('RemoteApp', 'Desktop')]
    [string]$ApplicationGroupType,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolArmPath,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$IdentityType,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Kind,

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
    [switch]$ShowInFeed,

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
    Name = $Name
    ResourceGroup = $ResourceGroup
    ApplicationGroupType = $ApplicationGroupType
    HostPoolArmPath = $HostPoolArmPath
    Location = $Location
}

if ($SubscriptionId) {
    $parameters['SubscriptionId'], $BgpCommunity
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

if ($Kind) {
    $parameters['Kind'], $Kind
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

if ($ShowInFeed) {
    $parameters['ShowInFeed'], $ShowInFeed
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
    # Create the application group and capture the result
    $result = New-AzWvdApplicationGroup @parameters

    # Output the result
    Write-Output "Application group created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the application group: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
