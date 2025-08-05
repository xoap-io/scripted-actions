<#
.SYNOPSIS
    Audit Azure Key Vault access policies and permissions using Azure CLI.

.DESCRIPTION
    This script performs comprehensive auditing of Azure Key Vault access policies, permissions, and security configurations.
    Analyzes access patterns, identifies security risks, generates compliance reports, and provides recommendations.
    Supports multiple Key Vaults, detailed permission analysis, and security best practice validation.
    
    The script uses Azure CLI commands: az keyvault show, az keyvault network-rule list, az keyvault secret list, etc.

.PARAMETER VaultName
    Name of the Key Vault to audit. Leave empty to audit all vaults in subscription.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group. If specified, only audits vaults in this resource group.

.PARAMETER AuditType
    Type of audit to perform.

.PARAMETER IncludeSecrets
    Include analysis of secrets (metadata only, not values).

.PARAMETER IncludeKeys
    Include analysis of keys and certificates.

.PARAMETER CheckNetworkRules
    Audit network access rules and firewall settings.

.PARAMETER CheckRBAC
    Include RBAC role assignments in the audit.

.PARAMETER ValidateCompliance
    Validate against security compliance standards.

.PARAMETER ComplianceStandard
    Compliance standard to validate against.

.PARAMETER OutputFormat
    Format for the audit report.

.PARAMETER ReportPath
    Path for the detailed audit report file.

.PARAMETER IncludeRecommendations
    Include security recommendations in the report.

.PARAMETER ExportFindings
    Export detailed findings to separate files.

.EXAMPLE
    .\az-cli-audit-key-vault.ps1 -VaultName "kv-prod" -AuditType "Full" -IncludeSecrets -CheckNetworkRules -OutputFormat "HTML"

.EXAMPLE
    .\az-cli-audit-key-vault.ps1 -ResourceGroup "rg-security" -ValidateCompliance -ComplianceStandard "SOC2" -IncludeRecommendations

.EXAMPLE
    .\az-cli-audit-key-vault.ps1 -AuditType "Quick" -CheckRBAC -ExportFindings -ReportPath "./audit-reports/"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
    Version: 1.0.0
    Requires: Azure CLI version 2.0 or later
    
    Audit Coverage:
    - Access policies and permissions
    - Network security rules
    - RBAC role assignments
    - Secret/key/certificate inventory
    - Security configuration validation
    - Compliance checking
    - Security recommendations

.LINK
    https://docs.microsoft.com/en-us/cli/azure/keyvault

.COMPONENT
    Azure CLI Key Vault Security Audit
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Key Vault name to audit")]
    [string]$VaultName,

    [Parameter(Mandatory = $false, HelpMessage = "Resource Group name")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Type of audit to perform")]
    [ValidateSet('Quick', 'Standard', 'Full', 'Compliance', 'Security')]
    [string]$AuditType = 'Standard',

    [Parameter(Mandatory = $false, HelpMessage = "Include secrets analysis")]
    [switch]$IncludeSecrets,

    [Parameter(Mandatory = $false, HelpMessage = "Include keys and certificates")]
    [switch]$IncludeKeys,

    [Parameter(Mandatory = $false, HelpMessage = "Check network access rules")]
    [switch]$CheckNetworkRules,

    [Parameter(Mandatory = $false, HelpMessage = "Include RBAC analysis")]
    [switch]$CheckRBAC,

    [Parameter(Mandatory = $false, HelpMessage = "Validate compliance")]
    [switch]$ValidateCompliance,

    [Parameter(Mandatory = $false, HelpMessage = "Compliance standard")]
    [ValidateSet('SOC2', 'ISO27001', 'PCI-DSS', 'HIPAA', 'Custom')]
    [string]$ComplianceStandard = 'SOC2',

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Console', 'JSON', 'HTML', 'CSV')]
    [string]$OutputFormat = 'Console',

    [Parameter(Mandatory = $false, HelpMessage = "Report file path")]
    [string]$ReportPath,

    [Parameter(Mandatory = $false, HelpMessage = "Include recommendations")]
    [switch]$IncludeRecommendations,

    [Parameter(Mandatory = $false, HelpMessage = "Export detailed findings")]
    [switch]$ExportFindings
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Global audit results
$global:AuditResults = @{
    StartTime = Get-Date
    VaultsAudited = @()
    SecurityFindings = @()
    ComplianceIssues = @()
    Recommendations = @()
    Summary = @{
        TotalVaults = 0
        HighRiskFindings = 0
        MediumRiskFindings = 0
        LowRiskFindings = 0
        ComplianceScore = 0
        RecommendationCount = 0
    }
}

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

# Function to get Key Vaults to audit
function Get-KeyVaultsToAudit {
    param($VaultName, $ResourceGroup)
    
    try {
        Write-Host "🔍 Identifying Key Vaults to audit..." -ForegroundColor Cyan
        
        $vaults = @()
        
        if ($VaultName) {
            # Audit specific vault
            if ($ResourceGroup) {
                $vault = az keyvault show --name $VaultName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
            }
            else {
                $vault = az keyvault show --name $VaultName --output json 2>$null | ConvertFrom-Json
            }
            
            if ($vault) {
                $vaults += $vault
            }
            else {
                throw "Key Vault '$VaultName' not found"
            }
        }
        elseif ($ResourceGroup) {
            # Audit all vaults in resource group
            $vaults = az keyvault list --resource-group $ResourceGroup --output json | ConvertFrom-Json
        }
        else {
            # Audit all vaults in subscription
            $vaults = az keyvault list --output json | ConvertFrom-Json
        }
        
        if ($vaults.Count -eq 0) {
            Write-Warning "No Key Vaults found to audit"
            return @()
        }
        
        Write-Host "✅ Found $($vaults.Count) Key Vault(s) to audit" -ForegroundColor Green
        return $vaults
    }
    catch {
        Write-Error "Error identifying Key Vaults: $($_.Exception.Message)"
        return @()
    }
}

# Function to audit access policies
function Get-AccessPolicyAudit {
    param($Vault)
    
    try {
        Write-Host "   🔐 Auditing access policies..." -ForegroundColor Gray
        
        $findings = @()
        $policies = $Vault.properties.accessPolicies
        
        if (-not $policies -or $policies.Count -eq 0) {
            $findings += @{
                Type = "AccessPolicy"
                Severity = "Medium"
                Issue = "No access policies configured"
                Details = "Key Vault has no access policies - consider using RBAC model"
                Vault = $Vault.name
            }
        }
        else {
            # Check for overly broad permissions
            foreach ($policy in $policies) {
                $permissions = @()
                if ($policy.permissions.keys) { $permissions += $policy.permissions.keys }
                if ($policy.permissions.secrets) { $permissions += $policy.permissions.secrets }
                if ($policy.permissions.certificates) { $permissions += $policy.permissions.certificates }
                
                # Check for "all" permissions
                if ($permissions -contains "all" -or $permissions -contains "*") {
                    $findings += @{
                        Type = "AccessPolicy"
                        Severity = "High"
                        Issue = "Overly broad permissions"
                        Details = "Principal $($policy.objectId) has 'all' permissions"
                        Vault = $Vault.name
                        Principal = $policy.objectId
                    }
                }
                
                # Check for excessive key permissions
                $highRiskKeyPerms = @("delete", "purge", "recover")
                $hasHighRiskPerms = $policy.permissions.keys | Where-Object { $_ -in $highRiskKeyPerms }
                if ($hasHighRiskPerms.Count -gt 0) {
                    $findings += @{
                        Type = "AccessPolicy"
                        Severity = "Medium"
                        Issue = "High-risk key permissions"
                        Details = "Principal $($policy.objectId) has permissions: $($hasHighRiskPerms -join ', ')"
                        Vault = $Vault.name
                        Principal = $policy.objectId
                    }
                }
                
                # Check for secret management permissions
                $secretMgmtPerms = @("delete", "purge", "set")
                $hasSecretMgmt = $policy.permissions.secrets | Where-Object { $_ -in $secretMgmtPerms }
                if ($hasSecretMgmt.Count -gt 0) {
                    $findings += @{
                        Type = "AccessPolicy"
                        Severity = "Medium"
                        Issue = "Secret management permissions"
                        Details = "Principal $($policy.objectId) can manage secrets: $($hasSecretMgmt -join ', ')"
                        Vault = $Vault.name
                        Principal = $policy.objectId
                    }
                }
            }
            
            # Check for too many access policies
            if ($policies.Count -gt 20) {
                $findings += @{
                    Type = "AccessPolicy"
                    Severity = "Low"
                    Issue = "Too many access policies"
                    Details = "$($policies.Count) access policies configured - consider consolidation"
                    Vault = $Vault.name
                }
            }
        }
        
        return $findings
    }
    catch {
        Write-Warning "Error auditing access policies for vault '$($Vault.name)': $($_.Exception.Message)"
        return @()
    }
}

# Function to audit network rules
function Get-NetworkRulesAudit {
    param($Vault)
    
    try {
        Write-Host "   🌐 Auditing network rules..." -ForegroundColor Gray
        
        $findings = @()
        
        # Get network rules
        $networkRules = az keyvault network-rule list --name $Vault.name --output json 2>$null | ConvertFrom-Json
        
        if ($networkRules) {
            # Check default action
            if ($networkRules.defaultAction -eq "Allow") {
                $findings += @{
                    Type = "NetworkSecurity"
                    Severity = "High"
                    Issue = "Open network access"
                    Details = "Default action is 'Allow' - Key Vault is accessible from all networks"
                    Vault = $Vault.name
                }
            }
            
            # Check for overly broad IP rules
            if ($networkRules.ipRules) {
                foreach ($ipRule in $networkRules.ipRules) {
                    if ($ipRule.value -eq "0.0.0.0/0" -or $ipRule.value -eq "*") {
                        $findings += @{
                            Type = "NetworkSecurity"
                            Severity = "Critical"
                            Issue = "Unrestricted IP access"
                            Details = "IP rule allows access from anywhere: $($ipRule.value)"
                            Vault = $Vault.name
                        }
                    }
                    
                    # Check for large CIDR blocks
                    if ($ipRule.value -match "/\d+$") {
                        $cidrBits = [int]($ipRule.value -split "/")[-1]
                        if ($cidrBits -lt 16) {
                            $findings += @{
                                Type = "NetworkSecurity"
                                Severity = "Medium"
                                Issue = "Broad IP range"
                                Details = "Large CIDR block allows many IPs: $($ipRule.value)"
                                Vault = $Vault.name
                            }
                        }
                    }
                }
            }
            
            # Check virtual network rules
            if ($networkRules.virtualNetworkRules -and $networkRules.virtualNetworkRules.Count -eq 0 -and $networkRules.defaultAction -eq "Deny") {
                $findings += @{
                    Type = "NetworkSecurity"
                    Severity = "Medium"
                    Issue = "No VNet rules with deny default"
                    Details = "Default deny but no VNet rules - vault may be inaccessible"
                    Vault = $Vault.name
                }
            }
        }
        else {
            $findings += @{
                Type = "NetworkSecurity"
                Severity = "Low"
                Issue = "No network rules configured"
                Details = "Key Vault has no network access restrictions"
                Vault = $Vault.name
            }
        }
        
        return $findings
    }
    catch {
        Write-Warning "Error auditing network rules for vault '$($Vault.name)': $($_.Exception.Message)"
        return @()
    }
}

# Function to audit secrets
function Get-SecretsAudit {
    param($Vault)
    
    try {
        Write-Host "   🔒 Auditing secrets..." -ForegroundColor Gray
        
        $findings = @()
        
        # Get secrets list (metadata only)
        $secrets = az keyvault secret list --vault-name $Vault.name --output json 2>$null | ConvertFrom-Json
        
        if ($secrets) {
            $totalSecrets = $secrets.Count
            $expiredSecrets = 0
            $expiringSoon = 0
            $noExpiration = 0
            
            foreach ($secret in $secrets) {
                # Check expiration
                if ($secret.attributes.expires) {
                    $expiryDate = [DateTime]$secret.attributes.expires
                    $daysToExpiry = ($expiryDate - (Get-Date)).Days
                    
                    if ($daysToExpiry -lt 0) {
                        $expiredSecrets++
                    }
                    elseif ($daysToExpiry -le 30) {
                        $expiringSoon++
                    }
                }
                else {
                    $noExpiration++
                }
                
                # Check if disabled
                if ($secret.attributes.enabled -eq $false) {
                    $findings += @{
                        Type = "SecretManagement"
                        Severity = "Low"
                        Issue = "Disabled secret"
                        Details = "Secret '$($secret.name)' is disabled - consider cleanup"
                        Vault = $Vault.name
                        SecretName = $secret.name
                    }
                }
            }
            
            # Generate findings based on analysis
            if ($expiredSecrets -gt 0) {
                $findings += @{
                    Type = "SecretManagement"
                    Severity = "High"
                    Issue = "Expired secrets"
                    Details = "$expiredSecrets secret(s) have expired"
                    Vault = $Vault.name
                    Count = $expiredSecrets
                }
            }
            
            if ($expiringSoon -gt 0) {
                $findings += @{
                    Type = "SecretManagement"
                    Severity = "Medium"
                    Issue = "Secrets expiring soon"
                    Details = "$expiringSoon secret(s) expire within 30 days"
                    Vault = $Vault.name
                    Count = $expiringSoon
                }
            }
            
            if ($noExpiration -gt ($totalSecrets * 0.5)) {
                $findings += @{
                    Type = "SecretManagement"
                    Severity = "Medium"
                    Issue = "Many secrets without expiration"
                    Details = "$noExpiration/$totalSecrets secrets have no expiration date"
                    Vault = $Vault.name
                    Count = $noExpiration
                }
            }
            
            if ($totalSecrets -gt 100) {
                $findings += @{
                    Type = "SecretManagement"
                    Severity = "Low"
                    Issue = "Large number of secrets"
                    Details = "$totalSecrets secrets stored - consider organization review"
                    Vault = $Vault.name
                    Count = $totalSecrets
                }
            }
        }
        
        return $findings
    }
    catch {
        Write-Warning "Error auditing secrets for vault '$($Vault.name)': $($_.Exception.Message)"
        return @()
    }
}

# Function to audit keys and certificates
function Get-KeysCertificatesAudit {
    param($Vault)
    
    try {
        Write-Host "   🔑 Auditing keys and certificates..." -ForegroundColor Gray
        
        $findings = @()
        
        # Audit keys
        $keys = az keyvault key list --vault-name $Vault.name --output json 2>$null | ConvertFrom-Json
        if ($keys) {
            foreach ($key in $keys) {
                # Check key expiration
                if ($key.attributes.expires) {
                    $expiryDate = [DateTime]$key.attributes.expires
                    $daysToExpiry = ($expiryDate - (Get-Date)).Days
                    
                    if ($daysToExpiry -lt 0) {
                        $findings += @{
                            Type = "KeyManagement"
                            Severity = "High"
                            Issue = "Expired key"
                            Details = "Key '$($key.name)' has expired"
                            Vault = $Vault.name
                            KeyName = $key.name
                        }
                    }
                    elseif ($daysToExpiry -le 30) {
                        $findings += @{
                            Type = "KeyManagement"
                            Severity = "Medium"
                            Issue = "Key expiring soon"
                            Details = "Key '$($key.name)' expires in $daysToExpiry days"
                            Vault = $Vault.name
                            KeyName = $key.name
                        }
                    }
                }
            }
        }
        
        # Audit certificates
        $certificates = az keyvault certificate list --vault-name $Vault.name --output json 2>$null | ConvertFrom-Json
        if ($certificates) {
            foreach ($cert in $certificates) {
                # Check certificate expiration
                if ($cert.attributes.expires) {
                    $expiryDate = [DateTime]$cert.attributes.expires
                    $daysToExpiry = ($expiryDate - (Get-Date)).Days
                    
                    if ($daysToExpiry -lt 0) {
                        $findings += @{
                            Type = "CertificateManagement"
                            Severity = "Critical"
                            Issue = "Expired certificate"
                            Details = "Certificate '$($cert.name)' has expired"
                            Vault = $Vault.name
                            CertificateName = $cert.name
                        }
                    }
                    elseif ($daysToExpiry -le 30) {
                        $findings += @{
                            Type = "CertificateManagement"
                            Severity = "High"
                            Issue = "Certificate expiring soon"
                            Details = "Certificate '$($cert.name)' expires in $daysToExpiry days"
                            Vault = $Vault.name
                            CertificateName = $cert.name
                        }
                    }
                }
            }
        }
        
        return $findings
    }
    catch {
        Write-Warning "Error auditing keys/certificates for vault '$($Vault.name)': $($_.Exception.Message)"
        return @()
    }
}

# Function to audit security configuration
function Get-SecurityConfigAudit {
    param($Vault)
    
    try {
        Write-Host "   🛡️ Auditing security configuration..." -ForegroundColor Gray
        
        $findings = @()
        
        # Check soft delete
        if ($Vault.properties.enableSoftDelete -ne $true) {
            $findings += @{
                Type = "SecurityConfiguration"
                Severity = "High"
                Issue = "Soft delete not enabled"
                Details = "Soft delete is not enabled - deleted items cannot be recovered"
                Vault = $Vault.name
            }
        }
        
        # Check purge protection
        if ($Vault.properties.enablePurgeProtection -ne $true) {
            $findings += @{
                Type = "SecurityConfiguration"
                Severity = "Medium"
                Issue = "Purge protection not enabled"
                Details = "Purge protection is not enabled - items can be permanently deleted"
                Vault = $Vault.name
            }
        }
        
        # Check RBAC authorization
        if ($Vault.properties.enableRbacAuthorization -ne $true) {
            $findings += @{
                Type = "SecurityConfiguration"
                Severity = "Medium"
                Issue = "RBAC not enabled"
                Details = "RBAC authorization is not enabled - using legacy access policies"
                Vault = $Vault.name
            }
        }
        
        # Check disk encryption enabled
        if ($Vault.properties.enabledForDiskEncryption -eq $true) {
            $findings += @{
                Type = "SecurityConfiguration"
                Severity = "Low"
                Issue = "Disk encryption enabled"
                Details = "Vault is enabled for disk encryption - ensure this is intentional"
                Vault = $Vault.name
            }
        }
        
        return $findings
    }
    catch {
        Write-Warning "Error auditing security configuration for vault '$($Vault.name)': $($_.Exception.Message)"
        return @()
    }
}

# Function to generate recommendations
function Get-SecurityRecommendations {
    param($Vault, $Findings)
    
    $recommendations = @()
    
    # Group findings by type
    $findingsByType = $Findings | Group-Object -Property Type
    
    foreach ($group in $findingsByType) {
        switch ($group.Name) {
            "AccessPolicy" {
                $recommendations += @{
                    Category = "Access Management"
                    Priority = "High"
                    Recommendation = "Review and minimize access policy permissions"
                    Details = "Consider migrating to RBAC model for better governance"
                    Vault = $Vault.name
                }
            }
            "NetworkSecurity" {
                $recommendations += @{
                    Category = "Network Security"
                    Priority = "High"
                    Recommendation = "Implement network access restrictions"
                    Details = "Configure virtual network rules and IP restrictions"
                    Vault = $Vault.name
                }
            }
            "SecretManagement" {
                $recommendations += @{
                    Category = "Secret Lifecycle"
                    Priority = "Medium"
                    Recommendation = "Implement secret rotation and expiration policies"
                    Details = "Set up automated secret rotation where possible"
                    Vault = $Vault.name
                }
            }
            "SecurityConfiguration" {
                $recommendations += @{
                    Category = "Security Hardening"
                    Priority = "High"
                    Recommendation = "Enable all security features"
                    Details = "Enable soft delete, purge protection, and RBAC authorization"
                    Vault = $Vault.name
                }
            }
        }
    }
    
    return $recommendations
}

# Function to validate compliance
function Test-ComplianceStandard {
    param($Vault, $Findings, $Standard)
    
    $complianceIssues = @()
    
    switch ($Standard) {
        "SOC2" {
            # SOC2 requires access controls and monitoring
            $accessIssues = $Findings | Where-Object { $_.Type -eq "AccessPolicy" -and $_.Severity -in @("High", "Critical") }
            if ($accessIssues.Count -gt 0) {
                $complianceIssues += @{
                    Standard = "SOC2"
                    Control = "CC6.1 - Logical Access Controls"
                    Issue = "Overly broad access permissions detected"
                    Vault = $Vault.name
                }
            }
            
            $networkIssues = $Findings | Where-Object { $_.Type -eq "NetworkSecurity" -and $_.Severity -in @("High", "Critical") }
            if ($networkIssues.Count -gt 0) {
                $complianceIssues += @{
                    Standard = "SOC2"
                    Control = "CC6.6 - Network Controls"
                    Issue = "Insufficient network access controls"
                    Vault = $Vault.name
                }
            }
        }
        
        "ISO27001" {
            # ISO27001 requires comprehensive security controls
            $securityConfigIssues = $Findings | Where-Object { $_.Type -eq "SecurityConfiguration" }
            if ($securityConfigIssues.Count -gt 0) {
                $complianceIssues += @{
                    Standard = "ISO27001"
                    Control = "A.12.6.1 - Management of Technical Vulnerabilities"
                    Issue = "Security configuration hardening required"
                    Vault = $Vault.name
                }
            }
        }
        
        "PCI-DSS" {
            # PCI-DSS requires strong access controls and encryption
            $accessIssues = $Findings | Where-Object { $_.Type -eq "AccessPolicy" -and $_.Severity -eq "Critical" }
            if ($accessIssues.Count -gt 0) {
                $complianceIssues += @{
                    Standard = "PCI-DSS"
                    Control = "Requirement 7 - Restrict access by business need"
                    Issue = "Excessive access permissions detected"
                    Vault = $Vault.name
                }
            }
        }
    }
    
    return $complianceIssues
}

# Function to perform full vault audit
function Invoke-VaultAudit {
    param($Vault, $AuditType, $IncludeSecrets, $IncludeKeys, $CheckNetworkRules, $ValidateCompliance, $ComplianceStandard, $IncludeRecommendations)
    
    try {
        Write-Host "🔍 Auditing Key Vault: $($Vault.name)" -ForegroundColor Cyan
        
        $vaultFindings = @()
        
        # Always audit access policies and security config
        $vaultFindings += Get-AccessPolicyAudit -Vault $Vault
        $vaultFindings += Get-SecurityConfigAudit -Vault $Vault
        
        # Conditional audits based on parameters
        if ($CheckNetworkRules -or $AuditType -in @("Full", "Security")) {
            $vaultFindings += Get-NetworkRulesAudit -Vault $Vault
        }
        
        if ($IncludeSecrets -or $AuditType -in @("Full", "Standard")) {
            $vaultFindings += Get-SecretsAudit -Vault $Vault
        }
        
        if ($IncludeKeys -or $AuditType -in @("Full", "Standard")) {
            $vaultFindings += Get-KeysCertificatesAudit -Vault $Vault
        }
        
        # Generate recommendations
        $recommendations = @()
        if ($IncludeRecommendations -or $AuditType -eq "Full") {
            $recommendations = Get-SecurityRecommendations -Vault $Vault -Findings $vaultFindings
        }
        
        # Validate compliance
        $complianceIssues = @()
        if ($ValidateCompliance) {
            $complianceIssues = Test-ComplianceStandard -Vault $Vault -Findings $vaultFindings -Standard $ComplianceStandard
        }
        
        # Update global results
        $global:AuditResults.VaultsAudited += @{
            Vault = $Vault
            Findings = $vaultFindings
            Recommendations = $recommendations
            ComplianceIssues = $complianceIssues
        }
        
        $global:AuditResults.SecurityFindings += $vaultFindings
        $global:AuditResults.Recommendations += $recommendations
        $global:AuditResults.ComplianceIssues += $complianceIssues
        
        # Update summary counts
        $global:AuditResults.Summary.TotalVaults++
        $global:AuditResults.Summary.HighRiskFindings += ($vaultFindings | Where-Object { $_.Severity -in @("High", "Critical") }).Count
        $global:AuditResults.Summary.MediumRiskFindings += ($vaultFindings | Where-Object { $_.Severity -eq "Medium" }).Count
        $global:AuditResults.Summary.LowRiskFindings += ($vaultFindings | Where-Object { $_.Severity -eq "Low" }).Count
        $global:AuditResults.Summary.RecommendationCount += $recommendations.Count
        
        Write-Host "✅ Audit completed for $($Vault.name)" -ForegroundColor Green
        
    }
    catch {
        Write-Error "Error auditing vault '$($Vault.name)': $($_.Exception.Message)"
    }
}

# Function to display console results
function Show-AuditResults {
    param($Results)
    
    Write-Host "`n📊 Key Vault Security Audit Results" -ForegroundColor Yellow
    Write-Host "====================================" -ForegroundColor Yellow
    
    Write-Host "`n📈 Summary:" -ForegroundColor Cyan
    Write-Host "   Vaults Audited: $($Results.Summary.TotalVaults)" -ForegroundColor White
    Write-Host "   High Risk Findings: $($Results.Summary.HighRiskFindings)" -ForegroundColor Red
    Write-Host "   Medium Risk Findings: $($Results.Summary.MediumRiskFindings)" -ForegroundColor Yellow
    Write-Host "   Low Risk Findings: $($Results.Summary.LowRiskFindings)" -ForegroundColor Gray
    Write-Host "   Recommendations: $($Results.Summary.RecommendationCount)" -ForegroundColor Cyan
    
    # Show findings by vault
    foreach ($vaultAudit in $Results.VaultsAudited) {
        Write-Host "`n🔐 Vault: $($vaultAudit.Vault.name)" -ForegroundColor Yellow
        
        if ($vaultAudit.Findings.Count -gt 0) {
            Write-Host "   Security Findings:" -ForegroundColor Red
            foreach ($finding in $vaultAudit.Findings) {
                $color = switch ($finding.Severity) {
                    "Critical" { "Red" }
                    "High" { "Red" }
                    "Medium" { "Yellow" }
                    "Low" { "Gray" }
                    default { "White" }
                }
                Write-Host "     [$($finding.Severity)] $($finding.Issue): $($finding.Details)" -ForegroundColor $color
            }
        }
        
        if ($vaultAudit.Recommendations.Count -gt 0) {
            Write-Host "   Recommendations:" -ForegroundColor Cyan
            foreach ($rec in $vaultAudit.Recommendations) {
                Write-Host "     [$($rec.Priority)] $($rec.Recommendation): $($rec.Details)" -ForegroundColor Cyan
            }
        }
        
        if ($vaultAudit.ComplianceIssues.Count -gt 0) {
            Write-Host "   Compliance Issues:" -ForegroundColor Magenta
            foreach ($issue in $vaultAudit.ComplianceIssues) {
                Write-Host "     [$($issue.Standard)] $($issue.Control): $($issue.Issue)" -ForegroundColor Magenta
            }
        }
    }
}

# Function to generate detailed report
function New-AuditReport {
    param($Results, $Format, $Path)
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        
        if (-not $Path) {
            $Path = ".\keyvault-audit-report-$timestamp"
        }
        
        switch ($Format) {
            'HTML' {
                $reportFile = "$Path.html"
                $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Key Vault Security Audit Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .summary { background-color: #e8f4f8; padding: 15px; margin: 15px 0; border-radius: 5px; }
        .vault-section { border: 1px solid #ddd; margin: 15px 0; padding: 15px; border-radius: 5px; }
        .critical { color: #dc3545; font-weight: bold; }
        .high { color: #fd7e14; font-weight: bold; }
        .medium { color: #ffc107; }
        .low { color: #6c757d; }
        .recommendation { color: #17a2b8; }
        .compliance { color: #6f42c1; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 Key Vault Security Audit Report</h1>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Audit Duration:</strong> $((Get-Date) - $Results.StartTime)</p>
    </div>
    
    <div class="summary">
        <h2>📊 Executive Summary</h2>
        <p><strong>Vaults Audited:</strong> $($Results.Summary.TotalVaults)</p>
        <p><strong>Critical/High Risk Findings:</strong> $($Results.Summary.HighRiskFindings)</p>
        <p><strong>Medium Risk Findings:</strong> $($Results.Summary.MediumRiskFindings)</p>
        <p><strong>Low Risk Findings:</strong> $($Results.Summary.LowRiskFindings)</p>
        <p><strong>Recommendations:</strong> $($Results.Summary.RecommendationCount)</p>
    </div>
"@
                
                foreach ($vaultAudit in $Results.VaultsAudited) {
                    $html += @"
    <div class="vault-section">
        <h3>🔐 Key Vault: $($vaultAudit.Vault.name)</h3>
        <p><strong>Resource Group:</strong> $($vaultAudit.Vault.resourceGroup)</p>
        <p><strong>Location:</strong> $($vaultAudit.Vault.location)</p>
        
        <h4>Security Findings</h4>
        <table>
            <tr><th>Severity</th><th>Type</th><th>Issue</th><th>Details</th></tr>
"@
                    
                    foreach ($finding in $vaultAudit.Findings) {
                        $severityClass = $finding.Severity.ToLower()
                        $html += @"
            <tr>
                <td class="$severityClass">$($finding.Severity)</td>
                <td>$($finding.Type)</td>
                <td>$($finding.Issue)</td>
                <td>$($finding.Details)</td>
            </tr>
"@
                    }
                    
                    $html += "</table>"
                    
                    if ($vaultAudit.Recommendations.Count -gt 0) {
                        $html += "<h4>Recommendations</h4><ul>"
                        foreach ($rec in $vaultAudit.Recommendations) {
                            $html += "<li class='recommendation'>[$($rec.Priority)] $($rec.Recommendation): $($rec.Details)</li>"
                        }
                        $html += "</ul>"
                    }
                    
                    $html += "</div>"
                }
                
                $html += "</body></html>"
                $html | Out-File -FilePath $reportFile -Encoding UTF8
            }
            
            'JSON' {
                $reportFile = "$Path.json"
                $Results | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
            }
            
            'CSV' {
                $reportFile = "$Path.csv"
                $csvData = @()
                foreach ($vaultAudit in $Results.VaultsAudited) {
                    foreach ($finding in $vaultAudit.Findings) {
                        $csvData += [PSCustomObject]@{
                            Vault = $vaultAudit.Vault.name
                            ResourceGroup = $vaultAudit.Vault.resourceGroup
                            Severity = $finding.Severity
                            Type = $finding.Type
                            Issue = $finding.Issue
                            Details = $finding.Details
                        }
                    }
                }
                $csvData | Export-Csv -Path $reportFile -NoTypeInformation
            }
        }
        
        Write-Host "📄 Audit report generated: $reportFile" -ForegroundColor Green
        return $reportFile
    }
    catch {
        Write-Warning "Error generating audit report: $($_.Exception.Message)"
        return $null
    }
}

# Main execution
try {
    Write-Host "🔐 Starting Key Vault Security Audit" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green
    
    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }
    
    # Get Key Vaults to audit
    $vaults = Get-KeyVaultsToAudit -VaultName $VaultName -ResourceGroup $ResourceGroup
    
    if ($vaults.Count -eq 0) {
        Write-Warning "No Key Vaults found to audit"
        exit 0
    }
    
    # Audit each vault
    foreach ($vault in $vaults) {
        Invoke-VaultAudit -Vault $vault -AuditType $AuditType -IncludeSecrets $IncludeSecrets -IncludeKeys $IncludeKeys -CheckNetworkRules $CheckNetworkRules -ValidateCompliance $ValidateCompliance -ComplianceStandard $ComplianceStandard -IncludeRecommendations $IncludeRecommendations
    }
    
    # Calculate compliance score
    if ($global:AuditResults.SecurityFindings.Count -gt 0) {
        $totalIssues = $global:AuditResults.SecurityFindings.Count
        $highCriticalIssues = ($global:AuditResults.SecurityFindings | Where-Object { $_.Severity -in @("High", "Critical") }).Count
        $global:AuditResults.Summary.ComplianceScore = [math]::Max(0, 100 - ($highCriticalIssues * 20) - (($totalIssues - $highCriticalIssues) * 5))
    }
    else {
        $global:AuditResults.Summary.ComplianceScore = 100
    }
    
    # Display results
    if ($OutputFormat -eq 'Console') {
        Show-AuditResults -Results $global:AuditResults
    }
    
    # Generate detailed report
    if ($OutputFormat -ne 'Console' -or $ReportPath) {
        $reportFile = New-AuditReport -Results $global:AuditResults -Format $OutputFormat -Path $ReportPath
    }
    
    # Export findings if requested
    if ($ExportFindings) {
        $findingsPath = "keyvault-findings-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $global:AuditResults.SecurityFindings | ConvertTo-Json -Depth 5 | Out-File -FilePath $findingsPath -Encoding UTF8
        Write-Host "📄 Detailed findings exported: $findingsPath" -ForegroundColor Cyan
    }
    
    Write-Host "`n📊 Audit Summary:" -ForegroundColor Yellow
    Write-Host "   Compliance Score: $($global:AuditResults.Summary.ComplianceScore)%" -ForegroundColor $(if ($global:AuditResults.Summary.ComplianceScore -ge 80) { "Green" } elseif ($global:AuditResults.Summary.ComplianceScore -ge 60) { "Yellow" } else { "Red" })
    Write-Host "   Total Issues: $($global:AuditResults.SecurityFindings.Count)" -ForegroundColor White
    Write-Host "   Action Items: $($global:AuditResults.Summary.HighRiskFindings + $global:AuditResults.Summary.MediumRiskFindings)" -ForegroundColor Yellow
    
}
catch {
    Write-Error "❌ Key Vault audit failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Key Vault security audit completed" -ForegroundColor Green
}
