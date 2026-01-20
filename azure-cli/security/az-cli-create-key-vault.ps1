<#
.SYNOPSIS
    Create an Azure Key Vault with security policies using Azure CLI.

.DESCRIPTION
    This script creates an Azure Key Vault using the Azure CLI with comprehensive security configuration and best practices.
    Supports access policies, network restrictions, advanced security features, and compliance settings.
    Includes RBAC configuration, soft delete, purge protection, and firewall rules.

    The script uses the Azure CLI command: az keyvault create

.PARAMETER Name
    Name of the Key Vault to create (must be globally unique).

.PARAMETER ResourceGroup
    Name of the Azure Resource Group where the Key Vault will be created.

.PARAMETER Location
    Azure region where the Key Vault will be created.

.PARAMETER Sku
    Key Vault SKU (Standard or Premium).

.PARAMETER EnabledForDeployment
    Enable Key Vault for Azure VM deployment access.

.PARAMETER EnabledForDiskEncryption
    Enable Key Vault for Azure Disk Encryption.

.PARAMETER EnabledForTemplateDeployment
    Enable Key Vault for ARM template deployment access.

.PARAMETER EnableSoftDelete
    Enable soft delete protection (recommended).

.PARAMETER SoftDeleteRetentionDays
    Soft delete retention period in days (7-90).

.PARAMETER EnablePurgeProtection
    Enable purge protection (prevents permanent deletion).

.PARAMETER EnableRbacAuthorization
    Use RBAC for access control instead of access policies.

.PARAMETER PublicNetworkAccess
    Public network access setting.

.PARAMETER DefaultAction
    Default network action for firewall.

.PARAMETER AllowedIpRanges
    Allowed IP ranges for network access (comma-separated).

.PARAMETER Tags
    Tags to apply to the Key Vault in key=value format (space-separated pairs).

.PARAMETER CreateAccessPolicy
    Create an initial access policy for the current user.

.EXAMPLE
    .\az-cli-create-key-vault.ps1 -Name "kv-prod-secrets" -ResourceGroup "rg-security" -Location "eastus" -Sku "Premium" -EnableSoftDelete -EnablePurgeProtection

.EXAMPLE
    .\az-cli-create-key-vault.ps1 -Name "kv-dev-keys" -ResourceGroup "rg-dev" -Location "westus2" -EnabledForDiskEncryption -EnableRbacAuthorization -Tags "Environment=Development Project=SecureApp"

.EXAMPLE
    .\az-cli-create-key-vault.ps1 -Name "kv-restricted" -ResourceGroup "rg-security" -Location "northeurope" -PublicNetworkAccess "Disabled" -DefaultAction "Deny" -AllowedIpRanges "203.0.113.0/24,198.51.100.0/24"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later

    Key Vault Security Best Practices:
    - Use Premium SKU for HSM-backed keys
    - Enable soft delete and purge protection
    - Implement network restrictions
    - Use RBAC for granular access control
    - Enable logging and monitoring
    - Rotate keys and secrets regularly

.LINK
    https://docs.microsoft.com/en-us/cli/azure/keyvault

.COMPONENT
    Azure CLI Key Vault Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Key Vault (globally unique)")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(3, 24)]
    [ValidatePattern('^[a-zA-Z0-9-]+$')]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Azure region for the Key Vault")]
    [ValidateNotNullOrEmpty()]
    [string]$Location,

    [Parameter(Mandatory = $false, HelpMessage = "Key Vault SKU")]
    [ValidateSet('Standard', 'Premium')]
    [string]$Sku = 'Standard',

    [Parameter(Mandatory = $false, HelpMessage = "Enable for VM deployment")]
    [switch]$EnabledForDeployment,

    [Parameter(Mandatory = $false, HelpMessage = "Enable for disk encryption")]
    [switch]$EnabledForDiskEncryption,

    [Parameter(Mandatory = $false, HelpMessage = "Enable for template deployment")]
    [switch]$EnabledForTemplateDeployment,

    [Parameter(Mandatory = $false, HelpMessage = "Enable soft delete")]
    [switch]$EnableSoftDelete,

    [Parameter(Mandatory = $false, HelpMessage = "Soft delete retention days")]
    [ValidateRange(7, 90)]
    [int]$SoftDeleteRetentionDays = 30,

    [Parameter(Mandatory = $false, HelpMessage = "Enable purge protection")]
    [switch]$EnablePurgeProtection,

    [Parameter(Mandatory = $false, HelpMessage = "Use RBAC authorization")]
    [switch]$EnableRbacAuthorization,

    [Parameter(Mandatory = $false, HelpMessage = "Public network access")]
    [ValidateSet('Enabled', 'Disabled')]
    [string]$PublicNetworkAccess = 'Enabled',

    [Parameter(Mandatory = $false, HelpMessage = "Default network action")]
    [ValidateSet('Allow', 'Deny')]
    [string]$DefaultAction = 'Allow',

    [Parameter(Mandatory = $false, HelpMessage = "Allowed IP ranges (comma-separated)")]
    [string]$AllowedIpRanges,

    [Parameter(Mandatory = $false, HelpMessage = "Tags in key=value format")]
    [string]$Tags,

    [Parameter(Mandatory = $false, HelpMessage = "Create access policy for current user")]
    [switch]$CreateAccessPolicy
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Function to validate Azure CLI installation and authentication
function Test-AzureCLI {
    try {
        Write-Host "🔍 Validating Azure CLI installation..." -ForegroundColor Cyan
        $null = az --version
        if ($LASTEXITCODE -ne 0) {
            throw "Azure CLI is not installed or not functioning correctly"
        }

        Write-Host "🔍 Checking Azure CLI authentication..." -ForegroundColor Cyan
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Not authenticated to Azure CLI. Please run 'az login' first"
        }

        Write-Host "✅ Azure CLI validation successful" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Azure CLI validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate resource group exists
function Test-ResourceGroupExists {
    param($ResourceGroup)

    try {
        Write-Host "🔍 Validating resource group '$ResourceGroup' exists..." -ForegroundColor Cyan
        $rg = az group show --name $ResourceGroup --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($rg)) {
            throw "Resource group '$ResourceGroup' not found"
        }
        Write-Host "✅ Resource group '$ResourceGroup' found" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Resource group validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to validate location
function Test-AzureLocation {
    param($Location)

    try {
        Write-Host "🔍 Validating Azure location '$Location'..." -ForegroundColor Cyan
        $validLocations = az account list-locations --query "[].name" --output tsv
        if ($validLocations -notcontains $Location) {
            throw "Invalid Azure location: $Location"
        }
        Write-Host "✅ Location '$Location' is valid" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Location validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to check Key Vault name availability
function Test-KeyVaultNameAvailability {
    param($VaultName)

    try {
        Write-Host "🔍 Checking Key Vault name availability..." -ForegroundColor Cyan
        $availability = az keyvault check-name --name $VaultName --output json | ConvertFrom-Json

        if (-not $availability.nameAvailable) {
            throw "Key Vault name '$VaultName' is not available. Reason: $($availability.reason). $($availability.message)"
        }

        Write-Host "✅ Key Vault name '$VaultName' is available" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Key Vault name validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to get current user information
function Get-CurrentUser {
    try {
        Write-Host "🔍 Getting current user information..." -ForegroundColor Cyan
        $account = az account show --query "user" --output json | ConvertFrom-Json

        $userInfo = @{
            Type = $account.type
            Name = $account.name
        }

        # Get object ID for the user
        if ($account.type -eq "user") {
            $objectId = az ad signed-in-user show --query "id" --output tsv 2>$null
            if ($LASTEXITCODE -eq 0) {
                $userInfo.ObjectId = $objectId
            }
        }

        Write-Host "✅ Current user: $($userInfo.Name) ($($userInfo.Type))" -ForegroundColor Green
        return $userInfo
    }
    catch {
        Write-Warning "Could not get current user information: $($_.Exception.Message)"
        return $null
    }
}

# Function to parse and validate tags
function Get-ValidatedTags {
    param($TagString)

    if ([string]::IsNullOrEmpty($TagString)) {
        return @()
    }

    $tagPairs = $TagString -split '\s+'
    $azTags = @()

    foreach ($pair in $tagPairs) {
        if ($pair -match '^([^=]+)=(.+)$') {
            $key = $Matches[1]
            $value = $Matches[2]

            # Validate tag key and value
            if ($key.Length -gt 512 -or $value.Length -gt 256) {
                throw "Tag key must be ≤ 512 chars and value ≤ 256 chars: $pair"
            }

            $azTags += $pair
        }
        else {
            throw "Invalid tag format: $pair (use key=value format)"
        }
    }

    return $azTags
}

# Function to parse and validate IP ranges
function Get-ValidatedIpRanges {
    param($IpRangeString)

    if ([string]::IsNullOrEmpty($IpRangeString)) {
        return @()
    }

    $ranges = $IpRangeString -split ','
    $validRanges = @()

    foreach ($range in $ranges) {
        $range = $range.Trim()

        # Validate CIDR notation or single IP
        if ($range -match '^(\d{1,3}\.){3}\d{1,3}(\/\d{1,2})?$') {
            # Validate IP address parts
            $ipPart = ($range -split '\/')[0]
            $octets = $ipPart -split '\.'

            $validIp = $true
            foreach ($octet in $octets) {
                if ([int]$octet -gt 255) {
                    $validIp = $false
                    break
                }
            }

            if ($validIp) {
                # Validate subnet mask if present
                if ($range -contains '/') {
                    $mask = ($range -split '\/')[1]
                    if ([int]$mask -gt 32) {
                        throw "Invalid subnet mask in IP range: $range"
                    }
                }
                $validRanges += $range
            }
            else {
                throw "Invalid IP address in range: $range"
            }
        }
        else {
            throw "Invalid IP range format: $range (use CIDR notation like 192.168.1.0/24)"
        }
    }

    return $validRanges
}

# Function to create access policy for current user
function New-UserAccessPolicy {
    param($VaultName, $ResourceGroup, $UserInfo)

    if (-not $UserInfo -or -not $UserInfo.ObjectId) {
        Write-Warning "Cannot create access policy - user object ID not available"
        return
    }

    try {
        Write-Host "🔧 Creating access policy for current user..." -ForegroundColor Cyan

        # Set comprehensive permissions for the user
        $permissions = @(
            'keyvault', 'set-policy',
            '--name', $VaultName,
            '--resource-group', $ResourceGroup,
            '--object-id', $UserInfo.ObjectId,
            '--key-permissions', 'get', 'list', 'create', 'delete', 'update', 'import', 'backup', 'restore', 'recover',
            '--secret-permissions', 'get', 'list', 'set', 'delete', 'backup', 'restore', 'recover',
            '--certificate-permissions', 'get', 'list', 'create', 'delete', 'update', 'import', 'backup', 'restore', 'recover'
        )

        $null = az @permissions

        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Access policy created for $($UserInfo.Name)" -ForegroundColor Green
        }
        else {
            Write-Warning "Failed to create access policy"
        }
    }
    catch {
        Write-Warning "Error creating access policy: $($_.Exception.Message)"
    }
}

# Function to configure network rules
function Set-NetworkRules {
    param($VaultName, $ResourceGroup, $DefaultAction, $IpRanges)

    if ($DefaultAction -eq 'Allow' -and $IpRanges.Count -eq 0) {
        return # No network restrictions needed
    }

    try {
        Write-Host "🔧 Configuring network access rules..." -ForegroundColor Cyan

        # Set default action
        $null = az keyvault update --name $VaultName --resource-group $ResourceGroup --default-action $DefaultAction

        # Add IP rules if provided
        if ($IpRanges.Count -gt 0) {
            foreach ($range in $IpRanges) {
                Write-Host "   Adding IP range: $range" -ForegroundColor Gray
                $null = az keyvault network-rule add --name $VaultName --resource-group $ResourceGroup --ip-address $range
            }
        }

        Write-Host "✅ Network rules configured" -ForegroundColor Green
    }
    catch {
        Write-Warning "Error configuring network rules: $($_.Exception.Message)"
    }
}

# Function to display Key Vault summary
function Show-KeyVaultSummary {
    param($Parameters)

    Write-Host "`n📋 Key Vault Configuration Summary:" -ForegroundColor Yellow
    Write-Host "   Vault Name: $($Parameters.Name)" -ForegroundColor White
    Write-Host "   Resource Group: $($Parameters.ResourceGroup)" -ForegroundColor White
    Write-Host "   Location: $($Parameters.Location)" -ForegroundColor White
    Write-Host "   SKU: $($Parameters.Sku)" -ForegroundColor White
    Write-Host "   Soft Delete: $($Parameters.EnableSoftDelete)" -ForegroundColor White
    Write-Host "   Purge Protection: $($Parameters.EnablePurgeProtection)" -ForegroundColor White
    Write-Host "   RBAC Authorization: $($Parameters.EnableRbacAuthorization)" -ForegroundColor White
    Write-Host "   Public Access: $($Parameters.PublicNetworkAccess)" -ForegroundColor White

    if ($Parameters.DefaultAction -eq 'Deny') {
        Write-Host "   Network Restrictions: Enabled" -ForegroundColor White
    }

    if ($Parameters.Tags) {
        Write-Host "   Tags: $($Parameters.Tags)" -ForegroundColor White
    }
    Write-Host ""
}

# Function to show security recommendations
function Show-SecurityRecommendations {
    param($VaultName, $EnableSoftDelete, $EnablePurgeProtection, $EnableRbac)

    Write-Host "`n🔒 Security Recommendations:" -ForegroundColor Yellow

    if (-not $EnableSoftDelete) {
        Write-Host "   ⚠️ Consider enabling soft delete for data protection" -ForegroundColor Red
    }

    if (-not $EnablePurgeProtection) {
        Write-Host "   ⚠️ Consider enabling purge protection for critical vaults" -ForegroundColor Red
    }

    if (-not $EnableRbac) {
        Write-Host "   💡 Consider using RBAC for more granular access control" -ForegroundColor Yellow
    }

    Write-Host "   📝 Next steps:" -ForegroundColor Cyan
    Write-Host "      1. Configure diagnostic settings for logging" -ForegroundColor White
    Write-Host "      2. Set up alerts for Key Vault access" -ForegroundColor White
    Write-Host "      3. Implement key rotation policies" -ForegroundColor White
    Write-Host "      4. Review and audit access policies regularly" -ForegroundColor White
    Write-Host "      5. Use managed identities for application access" -ForegroundColor White
    Write-Host ""
}

# Main execution
try {
    Write-Host "🚀 Starting Azure Key Vault Creation" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate resource group exists
    if (-not (Test-ResourceGroupExists -ResourceGroup $ResourceGroup)) {
        exit 1
    }

    # Validate location
    if (-not (Test-AzureLocation -Location $Location)) {
        exit 1
    }

    # Check Key Vault name availability
    if (-not (Test-KeyVaultNameAvailability -VaultName $Name)) {
        exit 1
    }

    # Get current user info for access policy
    $currentUser = $null
    if ($CreateAccessPolicy -or -not $EnableRbacAuthorization) {
        $currentUser = Get-CurrentUser
    }

    # Validate and process tags
    $validatedTags = @()
    if ($Tags) {
        $validatedTags = Get-ValidatedTags -TagString $Tags
    }

    # Validate IP ranges
    $validatedIpRanges = @()
    if ($AllowedIpRanges) {
        $validatedIpRanges = Get-ValidatedIpRanges -IpRangeString $AllowedIpRanges
    }

    # Display configuration summary
    $paramSummary = @{
        Name = $Name
        ResourceGroup = $ResourceGroup
        Location = $Location
        Sku = $Sku
        EnableSoftDelete = $EnableSoftDelete
        EnablePurgeProtection = $EnablePurgeProtection
        EnableRbacAuthorization = $EnableRbacAuthorization
        PublicNetworkAccess = $PublicNetworkAccess
        DefaultAction = $DefaultAction
        Tags = $Tags
    }
    Show-KeyVaultSummary -Parameters $paramSummary

    # Build parameters array
    $azParams = @(
        'keyvault', 'create',
        '--name', $Name,
        '--resource-group', $ResourceGroup,
        '--location', $Location,
        '--sku', $Sku
    )

    # Add security options
    if ($EnabledForDeployment) { $azParams += '--enabled-for-deployment', 'true' }
    if ($EnabledForDiskEncryption) { $azParams += '--enabled-for-disk-encryption', 'true' }
    if ($EnabledForTemplateDeployment) { $azParams += '--enabled-for-template-deployment', 'true' }
    if ($EnableSoftDelete) {
        $azParams += '--enable-soft-delete', 'true'
        $azParams += '--retention-days', $SoftDeleteRetentionDays.ToString()
    }
    if ($EnablePurgeProtection) { $azParams += '--enable-purge-protection', 'true' }
    if ($EnableRbacAuthorization) { $azParams += '--enable-rbac-authorization', 'true' }
    if ($PublicNetworkAccess -eq 'Disabled') { $azParams += '--public-network-access', 'Disabled' }

    # Add tags if provided
    if ($validatedTags.Count -gt 0) {
        $azParams += '--tags'
        $azParams += $validatedTags
    }

    # Create the Key Vault
    Write-Host "🔧 Creating Key Vault '$Name'..." -ForegroundColor Cyan
    $null = az @azParams

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Key Vault '$Name' created successfully!" -ForegroundColor Green

        # Configure network rules if needed
        if ($DefaultAction -eq 'Deny' -or $validatedIpRanges.Count -gt 0) {
            Set-NetworkRules -VaultName $Name -ResourceGroup $ResourceGroup -DefaultAction $DefaultAction -IpRanges $validatedIpRanges
        }

        # Create access policy for current user if not using RBAC
        if ($CreateAccessPolicy -and -not $EnableRbacAuthorization -and $currentUser) {
            New-UserAccessPolicy -VaultName $Name -ResourceGroup $ResourceGroup -UserInfo $currentUser
        }

        # Display created Key Vault details
        Write-Host "`n📝 Key Vault Details:" -ForegroundColor Yellow
        $vaultDetails = az keyvault show --name $Name --resource-group $ResourceGroup --output table
        Write-Host $vaultDetails -ForegroundColor White

        # Show Key Vault URI
        $vaultUri = az keyvault show --name $Name --resource-group $ResourceGroup --query "properties.vaultUri" --output tsv
        Write-Host "`n🔗 Key Vault URI: $vaultUri" -ForegroundColor Cyan

        # Show security recommendations
        Show-SecurityRecommendations -VaultName $Name -EnableSoftDelete $EnableSoftDelete -EnablePurgeProtection $EnablePurgeProtection -EnableRbac $EnableRbacAuthorization
    }
    else {
        throw "Failed to create Key Vault. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "❌ Failed to create Key Vault: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
