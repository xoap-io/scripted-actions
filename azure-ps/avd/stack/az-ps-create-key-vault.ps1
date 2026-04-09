<#
.SYNOPSIS
    Creates a new Azure Key Vault.

.DESCRIPTION
    This script creates a new Azure Key Vault with the specified parameters.
    Uses the New-AzKeyVault cmdlet from the Az.KeyVault module.

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

.PARAMETER Tags
    A hashtable of tags to apply to the Key Vault.

.PARAMETER NetworkRuleSet
    The network rule set for the Key Vault.

.EXAMPLE
    .\New-AzKeyVault.ps1 -Name "MyKeyVault" -ResourceGroup "MyResourceGroup" -Location "eastus" -Sku "Standard"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Az PowerShell module (Install-Module Az), Az.KeyVault

.LINK
    https://learn.microsoft.com/en-us/powershell/module/az.keyvault/new-azkeyvault?view=azps-12.3.0

.COMPONENT
    Azure PowerShell Key Vault
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, HelpMessage = "The name of the Key Vault.")]
    [ValidateNotNullOrEmpty()]
    [string]$Name,

    [Parameter(Mandatory=$true, HelpMessage = "The name of the Azure Resource Group.")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,

    [Parameter(Mandatory=$true, HelpMessage = "The Azure region where the Key Vault will be created.")]
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

    [Parameter(Mandatory=$false, HelpMessage = "Allow Azure VMs to retrieve certificates stored as secrets.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnabledForDeployment,

    [Parameter(Mandatory=$false, HelpMessage = "Allow Azure Resource Manager to retrieve secrets from the vault.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnabledForTemplateDeployment,

    [Parameter(Mandatory=$false, HelpMessage = "Allow Azure Disk Encryption to retrieve secrets and unwrap keys.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnabledForDiskEncryption,

    [Parameter(Mandatory=$false, HelpMessage = "Enable protection against purge for this key vault.")]
    [ValidateNotNullOrEmpty()]
    [switch]$EnablePurgeProtection,

    [Parameter(Mandatory=$false, HelpMessage = "Disable RBAC authorization for this key vault.")]
    [ValidateNotNullOrEmpty()]
    [switch]$DisableRbacAuthorization,

    [Parameter(Mandatory=$false, HelpMessage = "Number of days items are retained for soft delete (7-90).")]
    [ValidateRange(7, 90)]
    [int]$SoftDeleteRetentionInDays,

    [Parameter(Mandatory=$false, HelpMessage = "Public network access setting (Enabled or Disabled).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Enabled',
        'Disabled'
    )]
    [string]$PublicNetworkAccess,

    [Parameter(Mandatory=$true, HelpMessage = "The SKU of the Key Vault (Standard or Premium).")]
    [ValidateNotNullOrEmpty()]
    [ValidateSet(
        'Standard',
        'Premium'
    )]
    [string]$Sku,

    [Parameter(Mandatory=$false, HelpMessage = "A hashtable of tags to apply to the Key Vault.")]
    [ValidateNotNullOrEmpty()]
    [hashtable]$Tags,

    [Parameter(Mandatory=$false, HelpMessage = "The network rule set for the Key Vault.")]
    [ValidateNotNullOrEmpty()]
    [string]$NetworkRuleSet
)

# Set Error Action to Stop
$ErrorActionPreference = "Stop"

try {
    # Splatting parameters
    $params = @{
        Name = $Name
        ResourceGroupName = $ResourceGroup
        Location = $Location
    }

    if ($EnabledForDeployment) {
        $params['EnabledForDeployment'] = $true
    }

    if ($EnabledForTemplateDeployment) {
        $params['EnabledForTemplateDeployment'] = $true
    }

    if ($EnabledForDiskEncryption) {
        $params['EnabledForDiskEncryption'] = $true
    }

    if ($EnablePurgeProtection) {
        $params['EnablePurgeProtection'] = $true
    }

    if ($DisableRbacAuthorization) {
        $params['DisableRbacAuthorization'] = $true
    }

    if ($Sku) {
        $params['Sku'] = $Sku
    }

    if ($SoftDeleteRetentionInDays) {
        $params['SoftDeleteRetentionInDays'] = $SoftDeleteRetentionInDays
    }

    if ($PublicNetworkAccess) {
        $params['PublicNetworkAccess'] = $PublicNetworkAccess
    }

    if ($Tags) {
        $params['Tag'] = $Tags
    }

    if ($NetworkRuleSet) {
        $params['NetworkRuleSet'] = $NetworkRuleSet
    }

    # Create the Key Vault
    New-AzKeyVault @params
    Write-Host "✅ Key Vault '$Name' created successfully in resource group '$ResourceGroup' at location '$Location'." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
