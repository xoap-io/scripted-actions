<#
.SYNOPSIS
    Creates a new Azure Key Vault.

.DESCRIPTION
    This script creates a new Azure Key Vault with the specified parameters.

.PARAMETER Name
    The name of the Key Vault.

.PARAMETER ResourceGroup
    The name of the Azure Resource Group.

.PARAMETER Location
    The location of the Key Vault.

.PARAMETER EnabledForDeployment
    Indicates whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.

.PARAMETER EnabledForTemplateDeployment
    Indicates whether Azure Resource Manager is permitted to retrieve secrets from the key vault.

.PARAMETER EnabledForDiskEncryption
    Indicates whether Azure Disk Encryption is permitted to retrieve secrets from the key vault and unwrap keys.

.PARAMETER EnablePurgeProtection
    Indicates whether protection against purge is enabled for this key vault.

.PARAMETER DisableRbacAuthorization
    Indicates whether RBAC authorization is disabled for this key vault.

.PARAMETER SoftDeleteRetentionInDays
    The number of days that items should be retained for soft delete.

.PARAMETER PublicNetworkAccess
    The network access type for the Key Vault.

.PARAMETER Sku
    The SKU of the Key Vault.

.PARAMETER Tag
    A hashtable of tags to apply to the Key Vault.

.PARAMETER NetworkRuleSet
    The network rule set for the Key Vault.

.EXAMPLE
    .\New-AzKeyVault.ps1 -Name "MyKeyVault" -ResourceGroup "MyResourceGroup" -Location "eastus" -Sku "Standard"

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.keyvault

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.keyvault/new-azkeyvault?view=azps-12.3.0

.LINK
    https://github.com/scripted-actions

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
    [switch]$EnabledForDeployment,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnabledForTemplateDeployment,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnabledForDiskEncryption,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$EnablePurgeProtection,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableRbacAuthorization,

    [Parameter(Mandatory=$false)]
    [ValidateRange(7, 90)]
    [int]$SoftDeleteRetentionInDays,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Enabled',
        'Disabled'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Standard',
        'Premium'
    )]
    [string]$Sku,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$NetworkRuleSet
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Splatting parameters
    $params = @{
        Name = $Name
        ResourceGroup = $ResourceGroup
        Location = $Location
    }

        if ($EnabledForDeployment) {
        $params['EnabledForDeployment'], $true
    }

    if ($EnabledForTemplateDeployment) {
        $params['EnabledForTemplateDeployment'], $true
    }

    if ($EnabledForDiskEncryption) {
        $params['EnabledForDiskEncryption'], $true
    }

    if ($EnablePurgeProtection) {
        $params['EnablePurgeProtection'], $true
    }

    if ($DisableRbacAuthorization) {
        $params['DisableRbacAuthorization'], $true
    }

    if ($Sku) {
        $params['Sku'], $Sku
    }

    if ($SoftDeleteRetentionInDays) {
        $params['SoftDeleteRetentionInDays'], $SoftDeleteRetentionInDays
    }

    if ($PublicNetworkAccess) {
        $params['PublicNetworkAccess'], $PublicNetworkAccess
    }

    if ($Tag) {
        $params['Tag'], $Tag
    }

    if ($NetworkRuleSet) {
        $params['NetworkRuleSet'], $NetworkRuleSet
    }

    # Create the Key Vault
    New-AzKeyVault @params
    Write-Output "Key Vault '$Name' created successfully in resource group '$ResourceGroup' at location '$Location'."
}
catch {
    Write-Error "An error occurred while creating the Key Vault: $_"
}
