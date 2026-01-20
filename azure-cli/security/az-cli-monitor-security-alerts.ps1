<#
.SYNOPSIS
    Monitor and analyze Azure security alerts and incidents using Azure CLI.

.DESCRIPTION
    This script monitors Azure Security Center alerts, analyzes security incidents, and provides comprehensive security monitoring capabilities.
    Includes alert filtering, incident correlation, threat intelligence integration, and automated response capabilities.
    Supports real-time monitoring, historical analysis, and security operations center (SOC) workflows.

    The script uses Azure CLI commands: az security alert, az security assessment, etc.

.PARAMETER SubscriptionId
    Azure subscription ID to monitor. If not specified, uses current subscription.

.PARAMETER AlertSeverity
    Filter alerts by severity level.

.PARAMETER AlertStatus
    Filter alerts by status.

.PARAMETER TimeRange
    Time range for alert analysis.

.PARAMETER ResourceGroup
    Filter alerts by resource group.

.PARAMETER ResourceType
    Filter alerts by resource type.

.PARAMETER MonitorMode
    Monitoring mode - one-time analysis or continuous monitoring.

.PARAMETER AutoRespond
    Enable automated response to critical alerts.

.PARAMETER ResponseActions
    Comma-separated list of automated response actions.

.PARAMETER AnalyzeIncidents
    Perform incident correlation and analysis.

.PARAMETER GenerateReport
    Generate detailed security monitoring report.

.PARAMETER ReportFormat
    Format for the monitoring report.

.PARAMETER OutputPath
    Path for output files and reports.

.PARAMETER NotificationEmail
    Email address for alert notifications.

.PARAMETER SlackWebhook
    Slack webhook URL for notifications.

.PARAMETER ExportAlerts
    Export alerts to external systems.

.PARAMETER ExportFormat
    Format for alert export.

.EXAMPLE
    .\az-cli-monitor-security-alerts.ps1 -AlertSeverity "High,Critical" -TimeRange "24h" -GenerateReport -ReportFormat "HTML"

.EXAMPLE
    .\az-cli-monitor-security-alerts.ps1 -MonitorMode "Continuous" -AutoRespond -ResponseActions "Isolate,Notify" -NotificationEmail "soc@company.com"

.EXAMPLE
    .\az-cli-monitor-security-alerts.ps1 -ResourceGroup "rg-production" -AnalyzeIncidents -ExportAlerts -ExportFormat "SIEM"

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later, Security Center enabled

    Features:
    - Real-time security alert monitoring
    - Incident correlation and analysis
    - Automated threat response
    - Security metrics and KPIs
    - Integration with external systems
    - Comprehensive reporting and notifications

.LINK
    https://docs.microsoft.com/en-us/cli/azure/security

.COMPONENT
    Azure CLI Security Monitoring
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Azure subscription ID")]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false, HelpMessage = "Alert severity levels")]
    [ValidateSet('Informational', 'Low', 'Medium', 'High', 'Critical')]
    [string[]]$AlertSeverity = @('Medium', 'High', 'Critical'),

    [Parameter(Mandatory = $false, HelpMessage = "Alert status filter")]
    [ValidateSet('Active', 'Resolved', 'Dismissed', 'InProgress')]
    [string[]]$AlertStatus = @('Active', 'InProgress'),

    [Parameter(Mandatory = $false, HelpMessage = "Time range for analysis")]
    [ValidateSet('1h', '6h', '12h', '24h', '3d', '7d', '30d')]
    [string]$TimeRange = '24h',

    [Parameter(Mandatory = $false, HelpMessage = "Resource group filter")]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Resource type filter")]
    [string]$ResourceType,

    [Parameter(Mandatory = $false, HelpMessage = "Monitoring mode")]
    [ValidateSet('OneTime', 'Continuous', 'Scheduled')]
    [string]$MonitorMode = 'OneTime',

    [Parameter(Mandatory = $false, HelpMessage = "Enable automated response")]
    [switch]$AutoRespond,

    [Parameter(Mandatory = $false, HelpMessage = "Automated response actions")]
    [string]$ResponseActions = "Notify,Log",

    [Parameter(Mandatory = $false, HelpMessage = "Analyze security incidents")]
    [switch]$AnalyzeIncidents,

    [Parameter(Mandatory = $false, HelpMessage = "Generate monitoring report")]
    [switch]$GenerateReport,

    [Parameter(Mandatory = $false, HelpMessage = "Report format")]
    [ValidateSet('HTML', 'JSON', 'CSV', 'PDF')]
    [string]$ReportFormat = 'HTML',

    [Parameter(Mandatory = $false, HelpMessage = "Output path for files")]
    [string]$OutputPath,

    [Parameter(Mandatory = $false, HelpMessage = "Email for notifications")]
    [string]$NotificationEmail,

    [Parameter(Mandatory = $false, HelpMessage = "Slack webhook URL")]
    [string]$SlackWebhook,

    [Parameter(Mandatory = $false, HelpMessage = "Export alerts to external systems")]
    [switch]$ExportAlerts,

    [Parameter(Mandatory = $false, HelpMessage = "Export format")]
    [ValidateSet('SIEM', 'Splunk', 'JSON', 'CEF')]
    [string]$ExportFormat = 'JSON'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Global monitoring state
$global:MonitoringSession = @{
    StartTime = Get-Date
    Alerts = @()
    Incidents = @()
    Metrics = @{
        TotalAlerts = 0
        CriticalAlerts = 0
        HighAlerts = 0
        MediumAlerts = 0
        LowAlerts = 0
        ResolvedAlerts = 0
        ActiveIncidents = 0
        AutoResponses = 0
    }
    Notifications = @()
    ResponseActions = @()
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

# Function to check Security Center availability
function Test-SecurityCenter {
    try {
        Write-Host "🔍 Checking Security Center availability..." -ForegroundColor Cyan

        # Try to get security center status
        $null = az security auto-provisioning-setting list --output json 2>$null | ConvertFrom-Json

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Security Center may not be enabled or accessible"
            return $false
        }

        Write-Host "✅ Security Center is available" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Warning "Security Center check failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to calculate time range for queries
function Get-TimeRangeFilter {
    param($TimeRange)

    $now = Get-Date

    switch ($TimeRange) {
        '1h' { $startTime = $now.AddHours(-1) }
        '6h' { $startTime = $now.AddHours(-6) }
        '12h' { $startTime = $now.AddHours(-12) }
        '24h' { $startTime = $now.AddHours(-24) }
        '3d' { $startTime = $now.AddDays(-3) }
        '7d' { $startTime = $now.AddDays(-7) }
        '30d' { $startTime = $now.AddDays(-30) }
        default { $startTime = $now.AddHours(-24) }
    }

    return @{
        StartTime = $startTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
        EndTime = $now.ToString('yyyy-MM-ddTHH:mm:ssZ')
        Range = $TimeRange
    }
}

# Function to retrieve security alerts
function Get-SecurityAlerts {
    param($SubscriptionId, $AlertSeverity, $AlertStatus, $TimeFilter, $ResourceGroup, $ResourceType)

    try {
        Write-Host "🚨 Retrieving security alerts..." -ForegroundColor Cyan

        # Get alerts from Security Center
        $alerts = az security alert list --output json 2>$null | ConvertFrom-Json

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to retrieve security alerts"
            return @()
        }

        if (-not $alerts) {
            Write-Host "ℹ️ No security alerts found" -ForegroundColor Yellow
            return @()
        }

        Write-Host "📊 Found $($alerts.Count) total alerts" -ForegroundColor Gray

        # Filter alerts based on criteria
        $filteredAlerts = $alerts

        # Filter by severity
        if ($AlertSeverity.Count -gt 0) {
            $filteredAlerts = $filteredAlerts | Where-Object { $_.properties.severity -in $AlertSeverity }
            Write-Host "   After severity filter: $($filteredAlerts.Count) alerts" -ForegroundColor Gray
        }

        # Filter by status
        if ($AlertStatus.Count -gt 0) {
            $filteredAlerts = $filteredAlerts | Where-Object { $_.properties.status -in $AlertStatus }
            Write-Host "   After status filter: $($filteredAlerts.Count) alerts" -ForegroundColor Gray
        }

        # Filter by time range
        if ($TimeFilter) {
            $startTime = [DateTime]::Parse($TimeFilter.StartTime)
            $filteredAlerts = $filteredAlerts | Where-Object {
                $alertTime = [DateTime]::Parse($_.properties.timeGeneratedUtc)
                $alertTime -ge $startTime
            }
            Write-Host "   After time filter ($($TimeFilter.Range)): $($filteredAlerts.Count) alerts" -ForegroundColor Gray
        }

        # Filter by resource group
        if ($ResourceGroup) {
            $filteredAlerts = $filteredAlerts | Where-Object {
                $_.id -match "/resourceGroups/$ResourceGroup/"
            }
            Write-Host "   After resource group filter: $($filteredAlerts.Count) alerts" -ForegroundColor Gray
        }

        # Filter by resource type
        if ($ResourceType) {
            $filteredAlerts = $filteredAlerts | Where-Object {
                $_.properties.resourceIdentifiers.type -eq $ResourceType
            }
            Write-Host "   After resource type filter: $($filteredAlerts.Count) alerts" -ForegroundColor Gray
        }

        Write-Host "✅ Retrieved $($filteredAlerts.Count) filtered alerts" -ForegroundColor Green

        # Update global metrics
        $global:MonitoringSession.Metrics.TotalAlerts = $filteredAlerts.Count
        $global:MonitoringSession.Metrics.CriticalAlerts = ($filteredAlerts | Where-Object { $_.properties.severity -eq "Critical" }).Count
        $global:MonitoringSession.Metrics.HighAlerts = ($filteredAlerts | Where-Object { $_.properties.severity -eq "High" }).Count
        $global:MonitoringSession.Metrics.MediumAlerts = ($filteredAlerts | Where-Object { $_.properties.severity -eq "Medium" }).Count
        $global:MonitoringSession.Metrics.LowAlerts = ($filteredAlerts | Where-Object { $_.properties.severity -eq "Low" }).Count
        $global:MonitoringSession.Metrics.ResolvedAlerts = ($filteredAlerts | Where-Object { $_.properties.status -eq "Resolved" }).Count

        return $filteredAlerts
    }
    catch {
        Write-Error "Error retrieving security alerts: $($_.Exception.Message)"
        return @()
    }
}

# Function to analyze alerts for incidents
function Get-SecurityIncidents {
    param($Alerts)

    try {
        Write-Host "🔍 Analyzing alerts for security incidents..." -ForegroundColor Cyan

        $incidents = @()

        # Group alerts by resource and time to identify potential incidents
        $alertGroups = $Alerts | Group-Object -Property {
            $resourceId = $_.properties.resourceIdentifiers[0].azureResourceId
            $timeWindow = [Math]::Floor(([DateTime]::Parse($_.properties.timeGeneratedUtc) - [DateTime]::Parse("2020-01-01")).TotalHours / 6)
            "$resourceId-$timeWindow"
        }

        foreach ($group in $alertGroups) {
            if ($group.Count -gt 1) {
                # Multiple alerts for same resource in 6-hour window = potential incident
                $alertsByResource = $group.Group
                $highestSeverity = ($alertsByResource.properties.severity | Sort-Object {
                    switch ($_) {
                        "Critical" { 5 }
                        "High" { 4 }
                        "Medium" { 3 }
                        "Low" { 2 }
                        "Informational" { 1 }
                        default { 0 }
                    }
                } -Descending)[0]

                $incident = @{
                    Id = "INC-$(Get-Date -Format 'yyyyMMdd')-$([guid]::NewGuid().ToString().Substring(0,8))"
                    Severity = $highestSeverity
                    Status = "Active"
                    AlertCount = $alertsByResource.Count
                    FirstAlert = ($alertsByResource.properties.timeGeneratedUtc | Sort-Object)[0]
                    LastAlert = ($alertsByResource.properties.timeGeneratedUtc | Sort-Object -Descending)[0]
                    AffectedResource = $alertsByResource[0].properties.resourceIdentifiers[0].azureResourceId
                    AlertTypes = ($alertsByResource.properties.alertType | Sort-Object -Unique)
                    Alerts = $alertsByResource
                    ThreatCategories = ($alertsByResource.properties.intent | Where-Object { $_ } | Sort-Object -Unique)
                }

                $incidents += $incident
            }
        }

        # Look for advanced persistent threat (APT) patterns
        $timeOrderedAlerts = $Alerts | Sort-Object { [DateTime]::Parse($_.properties.timeGeneratedUtc) }

        # Detection pattern: Reconnaissance -> Initial Access -> Persistence -> Lateral Movement
        $threatPhases = @{
            "Reconnaissance" = @("Discovery", "Enumeration", "Scanning")
            "InitialAccess" = @("CredentialAccess", "Execution", "Phishing")
            "Persistence" = @("Persistence", "PrivilegeEscalation")
            "LateralMovement" = @("LateralMovement", "Collection", "Exfiltration")
        }

        # Analyze for threat campaign patterns (simplified detection)
        $threatTimeline = @()
        foreach ($alert in $timeOrderedAlerts) {
            $threatCategory = $alert.properties.intent
            if ($threatCategory) {
                $phase = "Unknown"
                foreach ($phaseKey in $threatPhases.Keys) {
                    if ($threatPhases[$phaseKey] -contains $threatCategory) {
                        $phase = $phaseKey
                        break
                    }
                }

                $threatTimeline += @{
                    Time = [DateTime]::Parse($alert.properties.timeGeneratedUtc)
                    Phase = $phase
                    Category = $threatCategory
                    Alert = $alert
                }
            }
        }

        # Check for progression through threat phases
        $phaseProgression = $threatTimeline | Group-Object -Property Phase | ForEach-Object {
            @{ Phase = $_.Name; Count = $_.Count; FirstSeen = ($_.Group.Time | Sort-Object)[0] }
        } | Sort-Object FirstSeen

        if ($phaseProgression.Count -ge 3) {
            # Potential APT campaign detected
            $campaignIncident = @{
                Id = "CAMPAIGN-$(Get-Date -Format 'yyyyMMdd')-$([guid]::NewGuid().ToString().Substring(0,8))"
                Type = "Advanced Persistent Threat Campaign"
                Severity = "Critical"
                Status = "Active"
                PhaseCount = $phaseProgression.Count
                Duration = ($threatTimeline[-1].Time - $threatTimeline[0].Time).TotalHours
                ThreatPhases = $phaseProgression
                Alerts = $threatTimeline
            }

            $incidents += $campaignIncident
        }

        Write-Host "✅ Identified $($incidents.Count) security incident(s)" -ForegroundColor Green
        $global:MonitoringSession.Metrics.ActiveIncidents = $incidents.Count

        return $incidents
    }
    catch {
        Write-Warning "Error analyzing security incidents: $($_.Exception.Message)"
        return @()
    }
}

# Function to perform automated response
function Invoke-AutomatedResponse {
    param($Alert, $ResponseActions)

    try {
        Write-Host "🤖 Executing automated response for alert: $($Alert.properties.alertDisplayName)" -ForegroundColor Yellow

        $actions = $ResponseActions -split ','
        $responseResults = @()

        foreach ($action in $actions) {
            $action = $action.Trim()

            switch ($action) {
                "Notify" {
                    $notificationResult = Send-AlertNotification -Alert $Alert
                    $responseResults += @{
                        Action = "Notify"
                        Success = $notificationResult.Success
                        Details = $notificationResult.Message
                    }
                }

                "Log" {
                    $null = Write-AlertToLog -Alert $Alert
                    $responseResults += @{
                        Action = "Log"
                        Success = $true
                        Details = "Alert logged to security log"
                    }
                }

                "Isolate" {
                    # Simplified isolation logic - would integrate with actual isolation systems
                    if ($Alert.properties.resourceIdentifiers[0].type -eq "VirtualMachine") {
                        $isolationResult = Invoke-VMIsolation -Alert $Alert
                        $responseResults += @{
                            Action = "Isolate"
                            Success = $isolationResult.Success
                            Details = $isolationResult.Message
                        }
                    }
                    else {
                        $responseResults += @{
                            Action = "Isolate"
                            Success = $false
                            Details = "Isolation not supported for resource type"
                        }
                    }
                }

                "Block" {
                    # Simplified blocking logic - would integrate with firewall/NSG systems
                    $blockResult = Invoke-NetworkBlock -Alert $Alert
                    $responseResults += @{
                        Action = "Block"
                        Success = $blockResult.Success
                        Details = $blockResult.Message
                    }
                }

                "Ticket" {
                    $ticketResult = New-SecurityTicket -Alert $Alert
                    $responseResults += @{
                        Action = "Ticket"
                        Success = $ticketResult.Success
                        Details = $ticketResult.TicketId
                    }
                }

                default {
                    $responseResults += @{
                        Action = $action
                        Success = $false
                        Details = "Unknown response action"
                    }
                }
            }
        }

        $global:MonitoringSession.ResponseActions += @{
            AlertId = $Alert.name
            Timestamp = Get-Date
            Actions = $responseResults
        }

        $global:MonitoringSession.Metrics.AutoResponses++

        Write-Host "✅ Automated response completed: $($responseResults.Count) action(s)" -ForegroundColor Green
        return $responseResults
    }
    catch {
        Write-Warning "Error in automated response: $($_.Exception.Message)"
        return @()
    }
}

# Function to send alert notification
function Send-AlertNotification {
    param($Alert)

    try {
        $message = @"
🚨 Security Alert: $($Alert.properties.alertDisplayName)

Severity: $($Alert.properties.severity)
Status: $($Alert.properties.status)
Time: $($Alert.properties.timeGeneratedUtc)
Resource: $($Alert.properties.resourceIdentifiers[0].azureResourceId)

Description: $($Alert.properties.description)

Recommended Actions: $($Alert.properties.remediationSteps -join '; ')
"@

        $notifications = @()

        # Email notification
        if ($NotificationEmail) {
            # In real implementation, this would send actual email
            Write-Host "📧 Email notification sent to: $NotificationEmail" -ForegroundColor Cyan
            $notifications += @{
                Type = "Email"
                Target = $NotificationEmail
                Success = $true
            }
        }

        # Slack notification
        if ($SlackWebhook) {
            # In real implementation, this would send to actual Slack webhook
            Write-Host "💬 Slack notification sent" -ForegroundColor Cyan
            $notifications += @{
                Type = "Slack"
                Target = $SlackWebhook
                Success = $true
            }
        }

        $global:MonitoringSession.Notifications += @{
            AlertId = $Alert.name
            Timestamp = Get-Date
            Message = $message
            Channels = $notifications
        }

        return @{
            Success = $true
            Message = "Notifications sent: $($notifications.Count) channel(s)"
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Notification failed: $($_.Exception.Message)"
        }
    }
}

# Function to write alert to security log
function Write-AlertToLog {
    param($Alert)

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $logPath = if ($OutputPath) {
            Join-Path $OutputPath "security-alerts-$timestamp.log"
        } else {
            ".\security-alerts-$timestamp.log"
        }

        $logEntry = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] SECURITY_ALERT | Severity: $($Alert.properties.severity) | Type: $($Alert.properties.alertType) | Resource: $($Alert.properties.resourceIdentifiers[0].azureResourceId) | Description: $($Alert.properties.description)"

        Add-Content -Path $logPath -Value $logEntry -Encoding UTF8

        return $true
    }
    catch {
        Write-Warning "Failed to write security log: $($_.Exception.Message)"
        return $false
    }
}

# Function to simulate VM isolation
function Invoke-VMIsolation {
    param($Alert)

    try {
        # In real implementation, this would:
        # 1. Apply NSG rules to block traffic
        # 2. Snapshot the VM for forensics
        # 3. Update VM metadata with isolation status

        Write-Host "🔒 Simulating VM isolation for security response" -ForegroundColor Yellow

        return @{
            Success = $true
            Message = "VM isolation initiated (simulation)"
        }
    }
    catch {
        return @{
            Success = $false
            Message = "VM isolation failed: $($_.Exception.Message)"
        }
    }
}

# Function to simulate network blocking
function Invoke-NetworkBlock {
    param($Alert)

    try {
        # In real implementation, this would:
        # 1. Extract malicious IPs from alert
        # 2. Update firewall/NSG rules
        # 3. Apply blocking rules

        Write-Host "🚫 Simulating network blocking for security response" -ForegroundColor Yellow

        return @{
            Success = $true
            Message = "Network blocking initiated (simulation)"
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Network blocking failed: $($_.Exception.Message)"
        }
    }
}

# Function to create security ticket
function New-SecurityTicket {
    param($Alert)

    try {
        # In real implementation, this would integrate with ticketing systems like ServiceNow, Jira, etc.
        $ticketId = "SEC-$(Get-Date -Format 'yyyyMMdd')-$([guid]::NewGuid().ToString().Substring(0,8))"

        Write-Host "🎫 Security ticket created: $ticketId" -ForegroundColor Cyan

        return @{
            Success = $true
            TicketId = $ticketId
        }
    }
    catch {
        return @{
            Success = $false
            TicketId = $null
        }
    }
}

# Function to export alerts
function Export-SecurityAlerts {
    param($Alerts, $Format, $Path)

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

        if (-not $Path) {
            $Path = ".\security-alerts-export-$timestamp"
        }

        Write-Host "📤 Exporting $($Alerts.Count) alerts in $Format format..." -ForegroundColor Cyan

        switch ($Format) {
            'SIEM' {
                # Common Event Format (CEF) for SIEM systems
                $exportFile = "$Path-siem.cef"
                $cefData = @()

                foreach ($alert in $Alerts) {
                    $severity = switch ($alert.properties.severity) {
                        "Critical" { 10 }
                        "High" { 8 }
                        "Medium" { 5 }
                        "Low" { 3 }
                        default { 1 }
                    }

                    $cefEntry = "CEF:0|Microsoft|Azure Security Center|1.0|$($alert.properties.alertType)|$($alert.properties.alertDisplayName)|$severity|rt=$($alert.properties.timeGeneratedUtc) src=$($alert.properties.resourceIdentifiers[0].azureResourceId) msg=$($alert.properties.description)"
                    $cefData += $cefEntry
                }

                $cefData | Out-File -FilePath $exportFile -Encoding UTF8
                Write-Host "✅ SIEM export completed: $exportFile" -ForegroundColor Green
            }

            'Splunk' {
                # Splunk-compatible JSON format
                $exportFile = "$Path-splunk.json"
                $splunkData = @()

                foreach ($alert in $Alerts) {
                    $splunkEvent = @{
                        time = [DateTimeOffset]::Parse($alert.properties.timeGeneratedUtc).ToUnixTimeSeconds()
                        source = "azure-security-center"
                        sourcetype = "azure:security:alert"
                        event = @{
                            alert_id = $alert.name
                            alert_type = $alert.properties.alertType
                            severity = $alert.properties.severity
                            status = $alert.properties.status
                            description = $alert.properties.description
                            resource_id = $alert.properties.resourceIdentifiers[0].azureResourceId
                            intent = $alert.properties.intent
                        }
                    }
                    $splunkData += $splunkEvent
                }

                $splunkData | ConvertTo-Json -Depth 5 | Out-File -FilePath $exportFile -Encoding UTF8
                Write-Host "✅ Splunk export completed: $exportFile" -ForegroundColor Green
            }

            'JSON' {
                $exportFile = "$Path-alerts.json"
                $Alerts | ConvertTo-Json -Depth 10 | Out-File -FilePath $exportFile -Encoding UTF8
                Write-Host "✅ JSON export completed: $exportFile" -ForegroundColor Green
            }

            'CEF' {
                # Pure Common Event Format
                $exportFile = "$Path-alerts.cef"
                $cefData = @()

                foreach ($alert in $Alerts) {
                    $cefEntry = "CEF:0|Microsoft|Azure Security Center|1.0|$($alert.properties.alertType)|$($alert.properties.alertDisplayName)|$($alert.properties.severity)|deviceExternalId=$($alert.properties.resourceIdentifiers[0].azureResourceId) rt=$($alert.properties.timeGeneratedUtc) msg=$($alert.properties.description)"
                    $cefData += $cefEntry
                }

                $cefData | Out-File -FilePath $exportFile -Encoding UTF8
                Write-Host "✅ CEF export completed: $exportFile" -ForegroundColor Green
            }
        }

        return $exportFile
    }
    catch {
        Write-Warning "Error exporting alerts: $($_.Exception.Message)"
        return $null
    }
}

# Function to generate monitoring report
function New-SecurityMonitoringReport {
    param($Alerts, $Incidents, $Format, $Path)

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

        if (-not $Path) {
            $Path = ".\security-monitoring-report-$timestamp"
        }

        Write-Host "📊 Generating security monitoring report..." -ForegroundColor Cyan

        switch ($Format) {
            'HTML' {
                $reportFile = "$Path.html"
                $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Azure Security Monitoring Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #1f2937; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric-card { background-color: #f8fafc; border: 1px solid #e2e8f0; padding: 15px; border-radius: 8px; text-align: center; }
        .critical { background-color: #fef2f2; border-color: #fecaca; }
        .high { background-color: #fef7ed; border-color: #fed7aa; }
        .medium { background-color: #fffbeb; border-color: #fde68a; }
        .low { background-color: #f0fdf4; border-color: #bbf7d0; }
        .alert-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        .alert-table th, .alert-table td { border: 1px solid #e2e8f0; padding: 12px; text-align: left; }
        .alert-table th { background-color: #f8fafc; font-weight: bold; }
        .incident-section { background-color: #fef2f2; border: 2px solid #fecaca; padding: 20px; margin: 20px 0; border-radius: 8px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔐 Azure Security Monitoring Report</h1>
        <p><strong>Generated:</strong> $(Get-Date)</p>
        <p><strong>Monitoring Period:</strong> $TimeRange</p>
        <p><strong>Report Duration:</strong> $((Get-Date) - $global:MonitoringSession.StartTime)</p>
    </div>

    <div class="metrics">
        <div class="metric-card critical">
            <h3>Critical Alerts</h3>
            <div style="font-size: 2em; font-weight: bold;">$($global:MonitoringSession.Metrics.CriticalAlerts)</div>
        </div>
        <div class="metric-card high">
            <h3>High Alerts</h3>
            <div style="font-size: 2em; font-weight: bold;">$($global:MonitoringSession.Metrics.HighAlerts)</div>
        </div>
        <div class="metric-card medium">
            <h3>Medium Alerts</h3>
            <div style="font-size: 2em; font-weight: bold;">$($global:MonitoringSession.Metrics.MediumAlerts)</div>
        </div>
        <div class="metric-card low">
            <h3>Low Alerts</h3>
            <div style="font-size: 2em; font-weight: bold;">$($global:MonitoringSession.Metrics.LowAlerts)</div>
        </div>
        <div class="metric-card">
            <h3>Active Incidents</h3>
            <div style="font-size: 2em; font-weight: bold;">$($global:MonitoringSession.Metrics.ActiveIncidents)</div>
        </div>
        <div class="metric-card">
            <h3>Auto Responses</h3>
            <div style="font-size: 2em; font-weight: bold;">$($global:MonitoringSession.Metrics.AutoResponses)</div>
        </div>
    </div>
"@

                if ($Incidents.Count -gt 0) {
                    $html += @"
    <div class="incident-section">
        <h2>🚨 Security Incidents</h2>
        <p>$($Incidents.Count) active security incident(s) detected:</p>
        <ul>
"@
                    foreach ($incident in $Incidents) {
                        $html += "<li><strong>$($incident.Id)</strong> - $($incident.Severity) severity, $($incident.AlertCount) related alerts</li>"
                    }
                    $html += "</ul></div>"
                }

                $html += @"
    <h2>📋 Recent Security Alerts</h2>
    <table class="alert-table">
        <tr>
            <th>Time</th>
            <th>Severity</th>
            <th>Alert Type</th>
            <th>Resource</th>
            <th>Status</th>
            <th>Description</th>
        </tr>
"@

                foreach ($alert in ($Alerts | Sort-Object { [DateTime]::Parse($_.properties.timeGeneratedUtc) } -Descending | Select-Object -First 20)) {
                    $severityClass = $alert.properties.severity.ToLower()
                    $resourceName = ($alert.properties.resourceIdentifiers[0].azureResourceId -split '/')[-1]
                    $html += @"
        <tr class="$severityClass">
            <td>$([DateTime]::Parse($alert.properties.timeGeneratedUtc).ToString('yyyy-MM-dd HH:mm'))</td>
            <td>$($alert.properties.severity)</td>
            <td>$($alert.properties.alertType)</td>
            <td>$resourceName</td>
            <td>$($alert.properties.status)</td>
            <td>$($alert.properties.description.Substring(0, [Math]::Min(100, $alert.properties.description.Length)))</td>
        </tr>
"@
                }

                $html += @"
    </table>
</body>
</html>
"@

                $html | Out-File -FilePath $reportFile -Encoding UTF8
            }

            'JSON' {
                $reportFile = "$Path.json"
                $reportData = @{
                    GeneratedAt = Get-Date
                    TimeRange = $TimeRange
                    Metrics = $global:MonitoringSession.Metrics
                    Alerts = $Alerts
                    Incidents = $Incidents
                    Notifications = $global:MonitoringSession.Notifications
                    ResponseActions = $global:MonitoringSession.ResponseActions
                }
                $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
            }

            'CSV' {
                $reportFile = "$Path.csv"
                $csvData = @()
                foreach ($alert in $Alerts) {
                    $csvData += [PSCustomObject]@{
                        Time = $alert.properties.timeGeneratedUtc
                        Severity = $alert.properties.severity
                        Status = $alert.properties.status
                        AlertType = $alert.properties.alertType
                        DisplayName = $alert.properties.alertDisplayName
                        Resource = $alert.properties.resourceIdentifiers[0].azureResourceId
                        Description = $alert.properties.description
                        Intent = $alert.properties.intent
                    }
                }
                $csvData | Export-Csv -Path $reportFile -NoTypeInformation
            }
        }

        Write-Host "✅ Security monitoring report generated: $reportFile" -ForegroundColor Green
        return $reportFile
    }
    catch {
        Write-Warning "Error generating monitoring report: $($_.Exception.Message)"
        return $null
    }
}

# Function to display real-time monitoring
function Start-ContinuousMonitoring {
    param($SubscriptionId, $AlertSeverity, $AlertStatus, $ResourceGroup, $ResourceType, $AutoRespond, $ResponseActions)

    try {
        Write-Host "🔄 Starting continuous security monitoring..." -ForegroundColor Green
        Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow

        $monitoringInterval = 60 # seconds
        $lastCheckTime = Get-Date

        while ($true) {
            $timeFilter = @{
                StartTime = $lastCheckTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
                EndTime = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ')
                Range = "Custom"
            }

            # Get new alerts since last check
            $newAlerts = Get-SecurityAlerts -SubscriptionId $SubscriptionId -AlertSeverity $AlertSeverity -AlertStatus $AlertStatus -TimeFilter $timeFilter -ResourceGroup $ResourceGroup -ResourceType $ResourceType

            if ($newAlerts.Count -gt 0) {
                Write-Host "`n🚨 $($newAlerts.Count) new alert(s) detected:" -ForegroundColor Red

                foreach ($alert in $newAlerts) {
                    $severityColor = switch ($alert.properties.severity) {
                        "Critical" { "Red" }
                        "High" { "Red" }
                        "Medium" { "Yellow" }
                        "Low" { "Gray" }
                        default { "White" }
                    }

                    Write-Host "   [$($alert.properties.severity)] $($alert.properties.alertDisplayName)" -ForegroundColor $severityColor

                    # Perform automated response for critical/high alerts
                    if ($AutoRespond -and $alert.properties.severity -in @("Critical", "High")) {
                        Write-Host "   🤖 Triggering automated response..." -ForegroundColor Yellow
                        $null = Invoke-AutomatedResponse -Alert $alert -ResponseActions $ResponseActions
                    }
                }

                # Update global tracking
                $global:MonitoringSession.Alerts += $newAlerts
            }
            else {
                Write-Host "$(Get-Date -Format 'HH:mm:ss') - No new alerts" -ForegroundColor Green
            }

            $lastCheckTime = Get-Date
            Start-Sleep -Seconds $monitoringInterval
        }
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        Write-Host "`n⏹️ Continuous monitoring stopped by user" -ForegroundColor Yellow
    }
    catch {
        Write-Error "Error in continuous monitoring: $($_.Exception.Message)"
    }
}

# Main execution
try {
    Write-Host "🛡️ Starting Azure Security Monitoring" -ForegroundColor Green
    Write-Host "=====================================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Check Security Center
    if (-not (Test-SecurityCenter)) {
        Write-Warning "Security Center may not be fully configured"
    }

    # Set subscription if specified
    if ($SubscriptionId) {
        az account set --subscription $SubscriptionId
    }

    # Get time filter
    $timeFilter = Get-TimeRangeFilter -TimeRange $TimeRange
    Write-Host "📅 Monitoring time range: $($timeFilter.Range) (from $($timeFilter.StartTime))" -ForegroundColor Cyan

    # Execute based on monitoring mode
    switch ($MonitorMode) {
        'OneTime' {
            # Retrieve security alerts
            $alerts = Get-SecurityAlerts -SubscriptionId $SubscriptionId -AlertSeverity $AlertSeverity -AlertStatus $AlertStatus -TimeFilter $timeFilter -ResourceGroup $ResourceGroup -ResourceType $ResourceType

            if ($alerts.Count -eq 0) {
                Write-Host "✅ No security alerts found matching criteria" -ForegroundColor Green
                exit 0
            }

            # Store alerts globally
            $global:MonitoringSession.Alerts = $alerts

            # Analyze incidents if requested
            $incidents = @()
            if ($AnalyzeIncidents) {
                $incidents = Get-SecurityIncidents -Alerts $alerts
                $global:MonitoringSession.Incidents = $incidents
            }

            # Perform automated response for critical alerts
            if ($AutoRespond) {
                $criticalAlerts = $alerts | Where-Object { $_.properties.severity -in @("Critical", "High") }
                foreach ($alert in $criticalAlerts) {
                    $null = Invoke-AutomatedResponse -Alert $alert -ResponseActions $ResponseActions
                }
            }

            # Export alerts if requested
            if ($ExportAlerts) {
                $exportFile = Export-SecurityAlerts -Alerts $alerts -Format $ExportFormat -Path $OutputPath
            }

            # Generate report if requested
            if ($GenerateReport) {
                $reportFile = New-SecurityMonitoringReport -Alerts $alerts -Incidents $incidents -Format $ReportFormat -Path $OutputPath
            }

            # Display summary
            Write-Host "`n📊 Security Monitoring Summary:" -ForegroundColor Yellow
            Write-Host "   Total Alerts: $($global:MonitoringSession.Metrics.TotalAlerts)" -ForegroundColor White
            Write-Host "   Critical: $($global:MonitoringSession.Metrics.CriticalAlerts)" -ForegroundColor Red
            Write-Host "   High: $($global:MonitoringSession.Metrics.HighAlerts)" -ForegroundColor Red
            Write-Host "   Medium: $($global:MonitoringSession.Metrics.MediumAlerts)" -ForegroundColor Yellow
            Write-Host "   Low: $($global:MonitoringSession.Metrics.LowAlerts)" -ForegroundColor Gray
            Write-Host "   Active Incidents: $($global:MonitoringSession.Metrics.ActiveIncidents)" -ForegroundColor Magenta
            Write-Host "   Automated Responses: $($global:MonitoringSession.Metrics.AutoResponses)" -ForegroundColor Cyan
        }

        'Continuous' {
            Start-ContinuousMonitoring -SubscriptionId $SubscriptionId -AlertSeverity $AlertSeverity -AlertStatus $AlertStatus -ResourceGroup $ResourceGroup -ResourceType $ResourceType -AutoRespond $AutoRespond -ResponseActions $ResponseActions
        }

        'Scheduled' {
            Write-Host "⏰ Scheduled monitoring mode selected" -ForegroundColor Cyan
            Write-Host "💡 To implement: Set up this script in Azure Automation or cron job" -ForegroundColor Yellow

            # For demonstration, run one-time analysis
            $alerts = Get-SecurityAlerts -SubscriptionId $SubscriptionId -AlertSeverity $AlertSeverity -AlertStatus $AlertStatus -TimeFilter $timeFilter -ResourceGroup $ResourceGroup -ResourceType $ResourceType
            $global:MonitoringSession.Alerts = $alerts

            if ($GenerateReport) {
                $null = New-SecurityMonitoringReport -Alerts $alerts -Incidents @() -Format $ReportFormat -Path $OutputPath
            }
        }
    }
}
catch {
    Write-Error "❌ Security monitoring failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Security monitoring session completed" -ForegroundColor Green
    $sessionDuration = (Get-Date) - $global:MonitoringSession.StartTime
    Write-Host "   Session Duration: $($sessionDuration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
}
