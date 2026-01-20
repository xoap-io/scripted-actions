<#
.SYNOPSIS
    Run comprehensive Azure security assessment using Azure CLI.

.DESCRIPTION
    This script performs a comprehensive Azure security assessment using the Azure CLI and Security Center.
    Analyzes security posture, compliance status, recommendations, and vulnerabilities across subscriptions.
    Includes resource security analysis, policy compliance checking, and detailed reporting capabilities.

    The script uses Azure CLI commands: az security and az policy

.PARAMETER Scope
    Assessment scope: Subscription, ResourceGroup, or specific resource.

.PARAMETER ResourceGroup
    Resource group name for scoped assessment.

.PARAMETER AssessmentType
    Type of security assessment to perform.

.PARAMETER IncludeRecommendations
    Include Azure Security Center recommendations.

.PARAMETER IncludeCompliance
    Include compliance assessment results.

.PARAMETER IncludeVulnerabilities
    Include vulnerability assessment results.

.PARAMETER IncludeAlerts
    Include security alerts analysis.

.PARAMETER OutputFormat
    Output format for results.

.PARAMETER ExportPath
    Export detailed results to file.

.PARAMETER Severity
    Filter by severity level.

.PARAMETER DetailLevel
    Level of detail in the assessment.

.PARAMETER GenerateReport
    Generate comprehensive HTML report.

.EXAMPLE
    .\az-cli-security-assessment.ps1 -Scope "Subscription" -AssessmentType "Full" -IncludeRecommendations -GenerateReport

.EXAMPLE
    .\az-cli-security-assessment.ps1 -Scope "ResourceGroup" -ResourceGroup "rg-production" -IncludeCompliance -IncludeVulnerabilities -ExportPath "security-report.json"

.EXAMPLE
    .\az-cli-security-assessment.ps1 -AssessmentType "Quick" -Severity "High,Critical" -OutputFormat "Summary"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later

    Security Assessment Areas:
    - Identity and Access Management
    - Network Security
    - Data Protection
    - Compute Security
    - Storage Security
    - Compliance Posture
    - Vulnerability Management

.LINK
    https://docs.microsoft.com/en-us/cli/azure/security

.COMPONENT
    Azure CLI Security Assessment
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Assessment scope")]
    [ValidateSet('Subscription', 'ResourceGroup', 'Resource')]
    [string]$Scope = 'Subscription',

    [Parameter(Mandatory = $false, HelpMessage = "Resource group name")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Assessment type")]
    [ValidateSet('Quick', 'Standard', 'Full', 'Compliance', 'Vulnerability')]
    [string]$AssessmentType = 'Standard',

    [Parameter(Mandatory = $false, HelpMessage = "Include Security Center recommendations")]
    [switch]$IncludeRecommendations,

    [Parameter(Mandatory = $false, HelpMessage = "Include compliance assessment")]
    [switch]$IncludeCompliance,

    [Parameter(Mandatory = $false, HelpMessage = "Include vulnerability assessment")]
    [switch]$IncludeVulnerabilities,

    [Parameter(Mandatory = $false, HelpMessage = "Include security alerts")]
    [switch]$IncludeAlerts,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'JSON', 'CSV', 'Summary', 'Detailed')]
    [string]$OutputFormat = 'Summary',

    [Parameter(Mandatory = $false, HelpMessage = "Export results to file")]
    [string]$ExportPath,

    [Parameter(Mandatory = $false, HelpMessage = "Filter by severity")]
    [ValidateSet('Low', 'Medium', 'High', 'Critical')]
    [string[]]$Severity = @('Medium', 'High', 'Critical'),

    [Parameter(Mandatory = $false, HelpMessage = "Assessment detail level")]
    [ValidateSet('Basic', 'Standard', 'Detailed')]
    [string]$DetailLevel = 'Standard',

    [Parameter(Mandatory = $false, HelpMessage = "Generate HTML report")]
    [switch]$GenerateReport
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

# Function to check Security Center availability
function Test-SecurityCenter {
    try {
        Write-Host "🔍 Checking Azure Security Center availability..." -ForegroundColor Cyan

        # Check if Security Center is available
        $pricing = az security pricing list --output json 2>$null | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0 -and $pricing) {
            Write-Host "✅ Azure Security Center is available" -ForegroundColor Green
            return $true
        }
        else {
            Write-Warning "⚠️ Azure Security Center may not be fully available or configured"
            return $false
        }
    }
    catch {
        Write-Warning "Could not verify Security Center status: $($_.Exception.Message)"
        return $false
    }
}

# Function to get subscription information
function Get-SubscriptionInfo {
    try {
        Write-Host "🔍 Getting subscription information..." -ForegroundColor Cyan
        $subscription = az account show --output json | ConvertFrom-Json

        $info = @{
            SubscriptionId = $subscription.id
            SubscriptionName = $subscription.name
            TenantId = $subscription.tenantId
            User = $subscription.user.name
            State = $subscription.state
        }

        Write-Host "✅ Subscription: $($info.SubscriptionName) ($($info.SubscriptionId))" -ForegroundColor Green
        return $info
    }
    catch {
        Write-Error "Failed to get subscription info: $($_.Exception.Message)"
        return $null
    }
}

# Function to assess Security Center recommendations
function Get-SecurityRecommendations {
    param($ResourceGroupFilter)

    try {
        Write-Host "🔍 Analyzing Security Center recommendations..." -ForegroundColor Cyan

        $recommendations = @()
        $taskList = az security task list --output json 2>$null | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0 -and $taskList) {
            foreach ($task in $taskList) {
                if (-not $ResourceGroupFilter -or $task.resourceGroup -eq $ResourceGroupFilter) {
                    $recommendations += @{
                        Name = $task.recommendationDisplayName
                        Severity = $task.subState
                        ResourceGroup = $task.resourceGroup
                        ResourceType = $task.resourceType
                        Description = $task.recommendationAdditionalData
                        State = $task.state
                    }
                }
            }
        }

        Write-Host "✅ Found $($recommendations.Count) recommendations" -ForegroundColor Green
        return $recommendations
    }
    catch {
        Write-Warning "Could not get security recommendations: $($_.Exception.Message)"
        return @()
    }
}

# Function to assess compliance posture
function Get-ComplianceAssessment {
    param($ResourceGroupFilter)

    try {
        Write-Host "🔍 Analyzing compliance posture..." -ForegroundColor Cyan

        $compliance = @{
            PolicyAssignments = @()
            ComplianceState = @()
            NonCompliantResources = @()
        }

        # Get policy assignments
        $assignments = az policy assignment list --output json 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -eq 0 -and $assignments) {
            foreach ($assignment in $assignments) {
                if (-not $ResourceGroupFilter -or $assignment.scope -like "*$ResourceGroupFilter*") {
                    $compliance.PolicyAssignments += @{
                        Name = $assignment.displayName
                        PolicyType = $assignment.policyDefinitionId.Split('/')[-1]
                        Scope = $assignment.scope
                        EnforcementMode = $assignment.enforcementMode
                    }
                }
            }
        }

        # Get compliance states
        $states = az policy state list --output json 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -eq 0 -and $states) {
            $compliance.ComplianceState = $states | Group-Object complianceState | ForEach-Object {
                @{
                    State = $_.Name
                    Count = $_.Count
                    Resources = $_.Group | ForEach-Object { $_.resourceId }
                }
            }
        }

        Write-Host "✅ Compliance assessment completed" -ForegroundColor Green
        return $compliance
    }
    catch {
        Write-Warning "Could not assess compliance: $($_.Exception.Message)"
        return @{}
    }
}

# Function to assess security alerts
function Get-SecurityAlerts {
    param($ResourceGroupFilter, $SeverityFilter)

    try {
        Write-Host "🔍 Analyzing security alerts..." -ForegroundColor Cyan

        $alerts = @()
        $alertList = az security alert list --output json 2>$null | ConvertFrom-Json

        if ($LASTEXITCODE -eq 0 -and $alertList) {
            foreach ($alert in $alertList) {
                if ((-not $ResourceGroupFilter -or $alert.resourceGroup -eq $ResourceGroupFilter) -and
                    ($SeverityFilter -contains $alert.severity)) {

                    $alerts += @{
                        Name = $alert.alertDisplayName
                        Severity = $alert.severity
                        Status = $alert.state
                        ResourceGroup = $alert.resourceGroup
                        DetectedTime = $alert.timeGeneratedUtc
                        Description = $alert.description
                        RemediationSteps = $alert.remediationSteps
                    }
                }
            }
        }

        Write-Host "✅ Found $($alerts.Count) security alerts" -ForegroundColor Green
        return $alerts
    }
    catch {
        Write-Warning "Could not get security alerts: $($_.Exception.Message)"
        return @()
    }
}

# Function to assess resource security
function Get-ResourceSecurityAssessment {
    param($ResourceGroupFilter)

    try {
        Write-Host "🔍 Analyzing resource security..." -ForegroundColor Cyan

        $assessment = @{
            NetworkSecurity = @()
            StorageSecurity = @()
            ComputeSecurity = @()
            DatabaseSecurity = @()
        }

        # Network Security Groups
        $nsgs = az network nsg list --output json 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -eq 0 -and $nsgs) {
            foreach ($nsg in $nsgs) {
                if (-not $ResourceGroupFilter -or $nsg.resourceGroup -eq $ResourceGroupFilter) {
                    $rules = az network nsg rule list --resource-group $nsg.resourceGroup --nsg-name $nsg.name --output json 2>$null | ConvertFrom-Json

                    # Check for overly permissive rules
                    $permissiveRules = $rules | Where-Object {
                        $_.sourceAddressPrefix -eq "*" -and $_.access -eq "Allow" -and $_.direction -eq "Inbound"
                    }

                    $assessment.NetworkSecurity += @{
                        ResourceName = $nsg.name
                        ResourceGroup = $nsg.resourceGroup
                        Type = "NetworkSecurityGroup"
                        Issues = @()
                        PermissiveRules = $permissiveRules.Count
                        TotalRules = $rules.Count
                    }

                    if ($permissiveRules.Count -gt 0) {
                        $assessment.NetworkSecurity[-1].Issues += "Has $($permissiveRules.Count) overly permissive inbound rules"
                    }
                }
            }
        }

        # Storage Accounts
        $storageAccounts = az storage account list --output json 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -eq 0 -and $storageAccounts) {
            foreach ($account in $storageAccounts) {
                if (-not $ResourceGroupFilter -or $account.resourceGroup -eq $ResourceGroupFilter) {
                    $issues = @()

                    if ($account.allowBlobPublicAccess) {
                        $issues += "Public blob access enabled"
                    }

                    if ($account.minimumTlsVersion -ne "TLS1_2") {
                        $issues += "TLS version less than 1.2"
                    }

                    if (-not $account.enableHttpsTrafficOnly) {
                        $issues += "HTTPS traffic not enforced"
                    }

                    $assessment.StorageSecurity += @{
                        ResourceName = $account.name
                        ResourceGroup = $account.resourceGroup
                        Type = "StorageAccount"
                        Issues = $issues
                        SecurityScore = if ($issues.Count -eq 0) { "Good" } elseif ($issues.Count -le 2) { "Fair" } else { "Poor" }
                    }
                }
            }
        }

        Write-Host "✅ Resource security assessment completed" -ForegroundColor Green
        return $assessment
    }
    catch {
        Write-Warning "Could not assess resource security: $($_.Exception.Message)"
        return @{}
    }
}

# Function to generate security score
function Get-SecurityScore {
    param($Recommendations, $Alerts, $Compliance, $ResourceAssessment)

    $score = 100
    $findings = @()

    # Deduct points for high/critical recommendations
    $criticalRecs = $Recommendations | Where-Object { $_.Severity -in @('High', 'Critical') }
    $score -= ($criticalRecs.Count * 5)
    if ($criticalRecs.Count -gt 0) {
        $findings += "Critical/High recommendations: $($criticalRecs.Count)"
    }

    # Deduct points for active alerts
    $activeAlerts = $Alerts | Where-Object { $_.Status -eq 'Active' }
    $score -= ($activeAlerts.Count * 10)
    if ($activeAlerts.Count -gt 0) {
        $findings += "Active security alerts: $($activeAlerts.Count)"
    }

    # Deduct points for non-compliant resources
    $nonCompliant = $Compliance.ComplianceState | Where-Object { $_.State -eq 'NonCompliant' }
    if ($nonCompliant) {
        $score -= ($nonCompliant.Count * 2)
        $findings += "Non-compliant resources: $($nonCompliant.Count)"
    }

    # Deduct points for resource security issues
    $networkIssues = $ResourceAssessment.NetworkSecurity | Where-Object { $_.Issues.Count -gt 0 }
    $storageIssues = $ResourceAssessment.StorageSecurity | Where-Object { $_.Issues.Count -gt 0 }
    $score -= (($networkIssues.Count + $storageIssues.Count) * 3)

    $score = [Math]::Max(0, $score)

    return @{
        Score = $score
        Grade = if ($score -ge 90) { "A" } elseif ($score -ge 80) { "B" } elseif ($score -ge 70) { "C" } elseif ($score -ge 60) { "D" } else { "F" }
        Findings = $findings
    }
}

# Function to format assessment results
function Format-AssessmentResults {
    param($Results, $Format)

    switch ($Format) {
        'Summary' {
            Write-Host "`n📊 Security Assessment Summary:" -ForegroundColor Yellow
            Write-Host "   Security Score: $($Results.SecurityScore.Score)/100 (Grade: $($Results.SecurityScore.Grade))" -ForegroundColor White
            Write-Host "   Recommendations: $($Results.Recommendations.Count)" -ForegroundColor White
            Write-Host "   Security Alerts: $($Results.Alerts.Count)" -ForegroundColor White
            Write-Host "   Compliance Issues: $($Results.Compliance.ComplianceState | Where-Object { $_.State -eq 'NonCompliant' } | Measure-Object -Property Count -Sum).Sum" -ForegroundColor White
            Write-Host "   Resource Issues: $(($Results.ResourceAssessment.NetworkSecurity + $Results.ResourceAssessment.StorageSecurity | Where-Object { $_.Issues.Count -gt 0 }).Count)" -ForegroundColor White
        }
        'Detailed' {
            Write-Host "`n📋 Detailed Assessment Results:" -ForegroundColor Yellow

            # Security Score
            Write-Host "`n🎯 Security Score: $($Results.SecurityScore.Score)/100 (Grade: $($Results.SecurityScore.Grade))" -ForegroundColor Cyan
            if ($Results.SecurityScore.Findings.Count -gt 0) {
                Write-Host "   Key Findings:" -ForegroundColor Yellow
                $Results.SecurityScore.Findings | ForEach-Object { Write-Host "   - $_" -ForegroundColor White }
            }

            # Top Recommendations
            if ($Results.Recommendations.Count -gt 0) {
                Write-Host "`n💡 Top Security Recommendations:" -ForegroundColor Cyan
                $Results.Recommendations | Where-Object { $_.Severity -in @('High', 'Critical') } | Select-Object -First 5 | ForEach-Object {
                    Write-Host "   [$($_.Severity)] $($_.Name)" -ForegroundColor Yellow
                }
            }

            # Active Alerts
            if ($Results.Alerts.Count -gt 0) {
                Write-Host "`n🚨 Active Security Alerts:" -ForegroundColor Cyan
                $Results.Alerts | Where-Object { $_.Status -eq 'Active' } | ForEach-Object {
                    Write-Host "   [$($_.Severity)] $($_.Name)" -ForegroundColor Red
                }
            }
        }
        'JSON' {
            return $Results | ConvertTo-Json -Depth 10
        }
        'CSV' {
            # Create flattened data for CSV export
            $csvData = @()
            foreach ($rec in $Results.Recommendations) {
                $csvData += [PSCustomObject]@{
                    Type = "Recommendation"
                    Name = $rec.Name
                    Severity = $rec.Severity
                    ResourceGroup = $rec.ResourceGroup
                    State = $rec.State
                }
            }
            return $csvData | ConvertTo-Csv -NoTypeInformation
        }
    }
}

# Function to generate HTML report
function New-HtmlReport {
    param($Results, $FilePath)

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure Security Assessment Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #0078d4; color: white; padding: 20px; border-radius: 5px; }
        .score { font-size: 24px; font-weight: bold; margin: 20px 0; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .critical { color: #d13438; }
        .high { color: #ff8c00; }
        .medium { color: #ffb900; }
        .low { color: #107c10; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Azure Security Assessment Report</h1>
        <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
        <p>Subscription: $($Results.SubscriptionInfo.SubscriptionName)</p>
    </div>

    <div class="score">
        Security Score: $($Results.SecurityScore.Score)/100 (Grade: $($Results.SecurityScore.Grade))
    </div>

    <div class="section">
        <h2>Summary</h2>
        <ul>
            <li>Recommendations: $($Results.Recommendations.Count)</li>
            <li>Security Alerts: $($Results.Alerts.Count)</li>
            <li>Compliance Issues: $(($Results.Compliance.ComplianceState | Where-Object { $_.State -eq 'NonCompliant' } | Measure-Object -Property Count -Sum).Sum)</li>
        </ul>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $FilePath -Encoding UTF8
    Write-Host "✅ HTML report generated: $FilePath" -ForegroundColor Green
}

# Main execution
try {
    Write-Host "🚀 Starting Azure Security Assessment" -ForegroundColor Green
    Write-Host "====================================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Check Security Center
    $securityCenterAvailable = Test-SecurityCenter

    # Get subscription info
    $subscriptionInfo = Get-SubscriptionInfo
    if (-not $subscriptionInfo) {
        exit 1
    }

    # Validate resource group if specified
    if ($ResourceGroup) {
        Write-Host "🔍 Validating resource group '$ResourceGroup'..." -ForegroundColor Cyan
        $null = az group show --name $ResourceGroup --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Resource group '$ResourceGroup' not found"
        }
        Write-Host "✅ Resource group validated" -ForegroundColor Green
    }

    # Initialize results
    $assessmentResults = @{
        SubscriptionInfo = $subscriptionInfo
        AssessmentType = $AssessmentType
        Scope = $Scope
        Timestamp = Get-Date
        Recommendations = @()
        Alerts = @()
        Compliance = @{}
        ResourceAssessment = @{}
        SecurityScore = @{}
    }

    # Perform assessments based on type and flags
    if ($AssessmentType -in @('Standard', 'Full') -or $IncludeRecommendations) {
        $assessmentResults.Recommendations = Get-SecurityRecommendations -ResourceGroupFilter $ResourceGroup
    }

    if ($AssessmentType -in @('Standard', 'Full') -or $IncludeAlerts) {
        $assessmentResults.Alerts = Get-SecurityAlerts -ResourceGroupFilter $ResourceGroup -SeverityFilter $Severity
    }

    if ($AssessmentType -in @('Full', 'Compliance') -or $IncludeCompliance) {
        $assessmentResults.Compliance = Get-ComplianceAssessment -ResourceGroupFilter $ResourceGroup
    }

    if ($AssessmentType -eq 'Full' -or $DetailLevel -eq 'Detailed') {
        $assessmentResults.ResourceAssessment = Get-ResourceSecurityAssessment -ResourceGroupFilter $ResourceGroup
    }

    # Calculate security score
    $assessmentResults.SecurityScore = Get-SecurityScore -Recommendations $assessmentResults.Recommendations -Alerts $assessmentResults.Alerts -Compliance $assessmentResults.Compliance -ResourceAssessment $assessmentResults.ResourceAssessment

    # Format and display results
    if ($OutputFormat -eq 'JSON' -or $ExportPath) {
        $output = Format-AssessmentResults -Results $assessmentResults -Format $OutputFormat

        if ($ExportPath) {
            if ($OutputFormat -eq 'JSON') {
                $output | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            else {
                $assessmentResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportPath -Encoding UTF8
            }
            Write-Host "✅ Results exported to: $ExportPath" -ForegroundColor Green
        }
        else {
            Write-Output $output
        }
    }
    else {
        Format-AssessmentResults -Results $assessmentResults -Format $OutputFormat
    }

    # Generate HTML report if requested
    if ($GenerateReport) {
        $reportPath = "security-assessment-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        New-HtmlReport -Results $assessmentResults -FilePath $reportPath
    }

    # Show recommendations based on score
    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    if ($assessmentResults.SecurityScore.Score -lt 70) {
        Write-Host "   1. Address critical and high severity recommendations immediately" -ForegroundColor Red
        Write-Host "   2. Review and resolve active security alerts" -ForegroundColor Red
        Write-Host "   3. Implement compliance policies for regulatory requirements" -ForegroundColor Yellow
    }
    elseif ($assessmentResults.SecurityScore.Score -lt 90) {
        Write-Host "   1. Review medium severity recommendations" -ForegroundColor Yellow
        Write-Host "   2. Enhance monitoring and alerting" -ForegroundColor Cyan
        Write-Host "   3. Consider implementing advanced security features" -ForegroundColor Cyan
    }
    else {
        Write-Host "   1. Maintain current security posture" -ForegroundColor Green
        Write-Host "   2. Regular security reviews and updates" -ForegroundColor Green
        Write-Host "   3. Monitor for new threats and vulnerabilities" -ForegroundColor Cyan
    }
}
catch {
    Write-Error "❌ Security assessment failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Security assessment completed" -ForegroundColor Green
}
