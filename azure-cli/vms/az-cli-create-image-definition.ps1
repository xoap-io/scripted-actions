<#
.SYNOPSIS
    Create a new Azure Image Definition in a Shared Image Gallery with the Azure CLI.

.DESCRIPTION
    This script creates a new Azure Image Definition in a Shared Image Gallery with the Azure CLI.
    The script uses the following Azure CLI command:
    az sig image-definition create --resource-group $AzResourceGroupName --gallery-name $AzGalleryName --gallery-image-definition $AzImageDefinition --publisher $AzImagePublisher --offer $AzImageOffer --sku $AzImageSku --os-type $AzImageType --os-state $AzOsState

.PARAMETER ImageDefinition
    Defines the name of the Azure Image Definition.

.PARAMETER GalleryName
    Defines the name of the Azure Shared Image Gallery.

.PARAMETER Offer
    Defines the offer of the Azure Image Definition.

.PARAMETER OsType
    Defines the OS type of the Azure Image Definition.

.PARAMETER Publisher
    Defines the publisher of the Azure Image Definition.

.PARAMETER ResourceGroup
    Defines the name of the Azure Resource Group.

.PARAMETER Sku
    Defines the SKU of the Azure Image Definition.

.PARAMETER Architecture
    Defines the architecture of the Azure Image Definition.

.PARAMETER Description
    Defines the description of the Azure Image Definition.

.PARAMETER DisallowedDiskTypes
    Defines the disallowed disk types of the Azure Image Definition.

.PARAMETER EndOfLifeDate
    Defines the end of life date of the Azure Image Definition.

.PARAMETER Eula
    Defines the EULA of the Azure Image Definition.

.PARAMETER Features
    Defines the features of the Azure Image Definition.

.PARAMETER HyperVGeneration
    Defines the Hyper-V generation of the Azure Image Definition.

.PARAMETER Location
    Defines the location of the Azure Image Definition.

.PARAMETER MaximumCpuCore
    Defines the maximum CPU core of the Azure Image Definition.

.PARAMETER MaximumMemory
    Defines the maximum memory of the Azure Image Definition.

.PARAMETER MinimumCpuCore
    Defines the minimum CPU core of the Azure Image Definition.

.PARAMETER MinimumMemory
    Defines the minimum memory of the Azure Image Definition.

.PARAMETER OsState
    Defines the OS state of the Azure Image Definition.

.PARAMETER PlanName
    Defines the plan name of the Azure Image Definition.

.PARAMETER PlanProduct
    Defines the plan product of the Azure Image Definition.

.PARAMETER PlanPublisher
    Defines the plan publisher of the Azure Image Definition.

.PARAMETER PrivacyStatementUri
    Defines the privacy statement URI of the Azure Image Definition.

.PARAMETER ReleaseNoteUri
    Defines the release note URI of the Azure Image Definition.

.PARAMETER Tags
    Defines the tags of the Azure Image Definition.

.EXAMPLE
    .\az-cli-create-image-definition.ps1 -ResourceGroupName "MyResourceGroup" -GalleryName "MyGallery" -ImageDefinition "MyImageDefinition" -ImagePublisher "MicrosoftWindowsDesktop" -ImageOffer "Windows-11" -ImageSku "win11-23h2-entn" -ImageType "Windows" -OsState "Generalized"

.LINK
    https://learn.microsoft.com/en-us/cli/azure/sig/image-definition

.LINK
    https://learn.microsoft.com/en-us/cli/azure/sig/image-definition?view=azure-cli-latest

.LINK
    https://github.com/xoap-io/scripted-actions

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ImageDefinition,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$GalleryName,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Offer,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Linux',
        'Windows'
    )]
    [string]$OsType,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Publisher,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$Sku,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Arm64',
        'x64'
    )]
    [string]$Architecture,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$DisallowedDiskTypes,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$EndOfLifeDate,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Eula,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Features,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'V1',
        'V2'
    )]
    [string]$HyperVGeneration,

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
    [int]$MaximumCpuCore,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$MaximumMemory,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$MinimumCpuCore,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [int]$MinimumMemory,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Generalized',
        'Specialized'
    )]
    [string]$OsState,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanName,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanProduct,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PlanPublisher,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$PrivacyStatementUri,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$ReleaseNoteUri,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$Tags
)

# Splatting parameters for better readability
$parameters = `
    '--gallery-image-definition',  $ImageDefinition,`
    '--gallery-name', $AzGalleryName,`
    '--offer', $AzImageOffer,`
    '--os-type', $AzImageType,`
    '--publisher', $AzImagePublisher,`
    '--resource-group', $AzResourceGroupName,`
    '--sku', $AzImageSku

if ($Architecture) {
    $parameters += '--architecture', $Architecture
}

if ($Description) {
    $parameters += '--description', $Description
}

if ($DisallowedDiskTypes) {
    $parameters += '--disallowed-disk-types', $DisallowedDiskTypes
}

if ($EndOfLifeDate) {
    $parameters += '--end-of-life-date', $EndOfLifeDate
}

if ($Eula) {
    $parameters += '--eula', $Eula
}

if ($Features) {
    $parameters += '--features', $Features
}

if ($HyperVGeneration) {
    $parameters += '--hyper-v-generation', $HyperVGeneration
}

if ($Location) {
    $parameters += '--location', $Location
}

if ($MaximumCpuCore) {
    $parameters += '--maximum-cpu-core', $MaximumCpuCore
}

if ($MaximumMemory) {
    $parameters += '--maximum-memory', $MaximumMemory
}

if ($MinimumCpuCore) {
    $parameters += '--minimum-cpu-core', $MinimumCpuCore
}

if ($MinimumMemory) {
    $parameters += '--minimum-memory', $MinimumMemory
}

if ($OsState) {
    $parameters += '--os-state', $OsState
}

if ($PlanName) {
    $parameters += '--plan-name', $PlanName
}

if ($PlanProduct) {
    $parameters += '--plan-product', $PlanProduct
}

if ($PlanPublisher) {
    $parameters += '--plan-publisher', $PlanPublisher
}

if ($PrivacyStatementUri) {
    $parameters += '--privacy-statement-uri', $PrivacyStatementUri
}

if ($ReleaseNoteUri) {
    $parameters += '--release-note-uri', $ReleaseNoteUri
}

if ($Tags) {
    $parameters += '--tags', $Tags
}

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Create a new Azure Image Definition
    az sig image-definition create @parameters

    # Output the result
    Write-Output "Azure Image Definition created successfully."

} catch {
    # Log the error to the console

    Write-Output "Error message $errorMessage"
    Write-Error "Failed to create the Azure Image Definition: $($_.Exception.Message)"

} finally {
    # Cleanup code if needed
    Write-Output "Script execution completed."
}
