<#
.SYNOPSIS
    Creates a new scaling plan in an Azure Virtual Desktop environment.

.DESCRIPTION
    This script creates a new scaling plan in an Azure Virtual Desktop environment with the specified parameters.
    Uses the New-AzWvdScalingPlan cmdlet from the Az.DesktopVirtualization module.

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

.PARAMETER HostPoolType
    The type of the host pool.

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

.PARAMETER SkuCapacity
    The SKU capacity of the scaling plan.

.PARAMETER SkuFamily
    The SKU family of the scaling plan.

.PARAMETER SkuName
    The SKU name of the scaling plan.

.PARAMETER SkuSize
    The SKU size of the scaling plan.

.PARAMETER Tags
    The tags for the scaling plan.

.EXAMPLE
    PS C:\> .\New-AzWvdScalingPlan.ps1 -Name "MyScalingPlan" -ResourceGroup "MyResourceGroup" -TimeZone "Pacific Standard Time" -Location "westeurope"

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
    https://learn.microsoft.com/en-us/powershell/module/az.desktopvirtualization/new-azwvdscalingplan?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Virtual Desktop

#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the resource group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The time zone for the scaling plan (e.g., 'Pacific Standard Time').")]
    [ValidateNotNullOrEmpty()]
    [string]$TimeZone,

    [Parameter(Mandatory=$false, HelpMessage = "The description of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false, HelpMessage = "The exclusion tag for the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$ExclusionTag,

    [Parameter(Mandatory=$false, HelpMessage = "The friendly display name of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$FriendlyName,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[IScalingHostPoolReference[]]$HostPoolReference,

    [Parameter(Mandatory=$false, HelpMessage = "The host pool type for the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$HostPoolType,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[ResourceIdentityType]$IdentityType,

    [Parameter(Mandatory=$false, HelpMessage = "The kind of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$Kind,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the scaling plan will be created.")]
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

    [Parameter(Mandatory=$false, HelpMessage = "The managed by property of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$ManagedBy,

    [Parameter(Mandatory=$false, HelpMessage = "The plan name of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanName,

    [Parameter(Mandatory=$false, HelpMessage = "The plan product of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanProduct,

    [Parameter(Mandatory=$false, HelpMessage = "The plan promotion code of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPromotionCode,

    [Parameter(Mandatory=$false, HelpMessage = "The plan publisher of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPublisher,

    [Parameter(Mandatory=$false, HelpMessage = "The plan version of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$PlanVersion,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[IScalingSchedule[]]$Schedule,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU capacity of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [int]$SkuCapacity,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU family of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuFamily,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU name of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuName,

    [Parameter(Mandatory=$false, HelpMessage = "The SKU size of the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [string]$SkuSize,

    # type currently not supported in scripted actions
    #[Parameter(Mandatory=$false)]
    #[ValidateNotNullOrEmpty()]
    #[SkuTier]$SkuTier,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the scaling plan.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Splatting parameters for better readability
    $parameters = @{
        Name              = $Name
        ResourceGroupName = $ResourceGroup
        TimeZone          = $TimeZone
        Location          = $Location
    }

    if ($Description) {
        $parameters['Description'] = $Description
    }

    if ($ExclusionTag) {
        $parameters['ExclusionTag'] = $ExclusionTag
    }

    if ($FriendlyName) {
        $parameters['FriendlyName'] = $FriendlyName
    }

    #if ($HostPoolReference) {
    #    $parameters['HostPoolReference'] = $HostPoolReference
    #}

    if ($HostPoolType) {
        $parameters['HostPoolType'] = $HostPoolType
    }

    #if ($IdentityType) {
    #    $parameters['IdentityType'] = $IdentityType
    #}

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

    #if ($Schedule) {
    #    $parameters['Schedule'] = $Schedule
    #}

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

    #if ($SkuTier) {
    #    $parameters['SkuTier'] = $SkuTier
    #}

    if ($Tags) {
        $parameters['Tag'] = $Tags
    }

    # Create the scaling plan and capture the result
    $result = New-AzWvdScalingPlan @parameters

    # Output the result
    Write-Host "✅ Scaling plan created successfully:" -ForegroundColor Green
    Write-Output $result

} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
