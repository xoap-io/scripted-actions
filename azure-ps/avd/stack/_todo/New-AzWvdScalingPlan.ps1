<#
.SYNOPSIS
Creates a new scaling plan in an Azure Virtual Desktop environment.

.DESCRIPTION
This script creates a new scaling plan in an Azure Virtual Desktop environment with the specified parameters.

.PARAMETER Name
The name of the scaling plan.

.PARAMETER ResourceGroup
The name of the resource group.


.PARAMETER TimeZone
The time zone for the scaling plan.

.PARAMETER Description
The description of the scaling plan.

.PARAMETER ExclusionTag
The exclusion tag for the scaling plan.

.PARAMETER FriendlyName
The friendly name of the scaling plan.

.PARAMETER HostPoolReference
References to host pools.

.PARAMETER HostPoolType
The type of the host pool.

.PARAMETER IdentityType
The identity type of the scaling plan.

.PARAMETER Kind
The kind of the scaling plan.

.PARAMETER Location
The location of the scaling plan.

.PARAMETER ManagedBy
The managed by property of the scaling plan.

.PARAMETER PlanName
The plan name of the scaling plan.

.PARAMETER PlanProduct
The plan product of the scaling plan.

.PARAMETER PlanPromotionCode
The plan promotion code of the scaling plan.

.PARAMETER PlanPublisher
The plan publisher of the scaling plan.

.PARAMETER PlanVersion
The plan version of the scaling plan.

.PARAMETER Schedule
The schedule for the scaling plan.

.PARAMETER SkuCapacity
The SKU capacity of the scaling plan.

.PARAMETER SkuFamily
The SKU family of the scaling plan.

.PARAMETER SkuName
The SKU name of the scaling plan.

.PARAMETER SkuSize
The SKU size of the scaling plan.

.PARAMETER SkuTier
The SKU tier of the scaling plan.

.PARAMETER Tag
The tags for the scaling plan.


.EXAMPLE
PS C:\> .\New-AzWvdScalingPlan.ps1 -Name "MyScalingPlan" -ResourceGroup "MyResourceGroup" -TimeZone "Pacific Standard Time"
#>

param (
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Name = 'MyScalingPlan',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup = 'MyResourceGroup',

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$TimeZone = 'Pacific Standard Time',

    [string]$Description,

    [string]$ExclusionTag,

    [string]$FriendlyName,

    [IScalingHostPoolReference[]]$HostPoolReference,

    [ScalingHostPoolType]$HostPoolType,

    [ResourceIdentityType]$IdentityType,

    [string]$Kind,

    [Parameter(Mandatory=$true)]
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
    [string]$Location = 'westeurope',

    [string]$ManagedBy,

    [string]$PlanName,

    [string]$PlanProduct,

    [string]$PlanPromotionCode,

    [string]$PlanPublisher,

    [string]$PlanVersion,

    [IScalingSchedule[]]$Schedule,

    [int]$SkuCapacity,

    [string]$SkuFamily,

    [string]$SkuName,

    [string]$SkuSize,

    [SkuTier]$SkuTier,

    [hashtable]$Tag
)

try {
    # Splatting parameters for better readability
    $parameters = @{
        Name                = $Name
        ResourceGroup   = $ResourceGroup
        SubscriptionId      = $SubscriptionId
        TimeZone            = $TimeZone
        }

    if ($Description) {
        $parameters['Description', $Description
    }

    if ($ExclusionTag) {
        $parameters['ExclusionTag', $ExclusionTag
    }

    if ($FriendlyName) {
        $parameters['FriendlyName', $FriendlyName
    }

    if ($HostPoolReference) {
        $parameters['HostPoolReference', $HostPoolReference
    }

    if ($HostPoolType) {
        $parameters['HostPoolType', $HostPoolType
    }

    if ($IdentityType) {
        $parameters['IdentityType', $IdentityType
    }

    if ($Kind) {
        $parameters['Kind', $Kind
    }

    if ($Location) {
        $parameters['Location', $Location
    }

    if ($ManagedBy) {
        $parameters['ManagedBy', $ManagedBy
    }

    if ($PlanName) {
        $parameters['PlanName', $PlanName
    }

    if ($PlanProduct) {
        $parameters['PlanProduct', $PlanProduct
    }

    if ($PlanPromotionCode) {
        $parameters['PlanPromotionCode', $PlanPromotionCode
    }

    if ($PlanPublisher) {
        $parameters['PlanPublisher', $PlanPublisher
    }

    if ($PlanVersion) {
        $parameters['PlanVersion', $PlanVersion
    }

    if ($Schedule) {
        $parameters['Schedule', $Schedule
    }

    if ($SkuCapacity) {
        $parameters['SkuCapacity', $SkuCapacity
    }

    if ($SkuFamily) {
        $parameters['SkuFamily', $SkuFamily
    }

    if ($SkuName) {
        $parameters['SkuName', $SkuName
    }

    if ($SkuSize) {
        $parameters['SkuSize', $SkuSize
    }

    if ($SkuTier) {
        $parameters['SkuTier', $SkuTier
    }

    if ($Tags) {
        $parameters['Tag', $Tags
    }

    # Create the scaling plan and capture the result
    $result = New-AzWvdScalingPlan @parameters

    # Output the result
    Write-Output "Scaling plan created successfully:"
    Write-Output $result

} catch [System.Exception] {

    Write-Error "Failed to create the scaling plan: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
