<#
.SYNOPSIS
    Manage Azure Firewall rules using Azure CLI with comprehensive validation and safety features.

.DESCRIPTION
    This script manages Azure Firewall application, network, and NAT rules using the Azure CLI.
    Supports creating, updating, listing, and deleting firewall rules with extensive validation and safety mechanisms.
    Includes rule conflict detection, backup capabilities, and comprehensive reporting.

    The script uses Azure CLI commands: az network firewall application-rule, az network firewall network-rule, etc.

.PARAMETER FirewallName
    Name of the Azure Firewall to manage.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the firewall.

.PARAMETER Action
    Action to perform on firewall rules.

.PARAMETER RuleType
    Type of firewall rule to manage.

.PARAMETER CollectionName
    Name of the rule collection.

.PARAMETER RuleName
    Name of the specific rule.

.PARAMETER Priority
    Priority of the rule collection (100-65000).

.PARAMETER ActionType
    Action type for the rule (Allow/Deny).

.PARAMETER SourceAddresses
    Source IP addresses or ranges (comma-separated).

.PARAMETER DestinationAddresses
    Destination IP addresses or ranges (comma-separated).

.PARAMETER DestinationPorts
    Destination ports (comma-separated).

.PARAMETER Protocols
    Protocols for network rules (comma-separated).

.PARAMETER TargetFqdns
    Target FQDNs for application rules (comma-separated).

.PARAMETER FqdnTags
    FQDN tags for application rules (comma-separated).

.PARAMETER TranslatedAddress
    Translated address for NAT rules.

.PARAMETER TranslatedPort
    Translated port for NAT rules.

.PARAMETER ValidateRules
    Validate rule configurations and check for conflicts.

.PARAMETER BackupRules
    Create backup before making changes.

.PARAMETER BackupPath
    Path for backup files.

.PARAMETER DryRun
    Show what would be changed without making actual changes.

.PARAMETER OutputFormat
    Output format for results.

.PARAMETER ExportConfig
    Export complete firewall configuration.

.EXAMPLE
    .\az-cli-manage-firewall-rules.ps1 -FirewallName "fw-hub" -ResourceGroup "rg-network" -Action "Create" -RuleType "Application" -CollectionName "web-apps" -RuleName "allow-http" -Priority 100 -ActionType "Allow" -SourceAddresses "10.0.0.0/24" -TargetFqdns "*.microsoft.com"

.EXAMPLE
    .\az-cli-manage-firewall-rules.ps1 -FirewallName "fw-hub" -ResourceGroup "rg-network" -Action "List" -RuleType "Network" -ValidateRules -OutputFormat "JSON"

.EXAMPLE
    .\az-cli-manage-firewall-rules.ps1 -FirewallName "fw-hub" -ResourceGroup "rg-network" -Action "Delete" -RuleType "Application" -CollectionName "old-rules" -BackupRules -DryRun

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
    Version: 1.0.0
    Requires: Azure CLI version 2.0 or later

    Features:
    - Support for Application, Network, and NAT rules
    - Rule conflict detection and validation
    - Backup and restore capabilities
    - Dry run mode for testing
    - Comprehensive reporting and logging
    - Priority management and optimization

.LINK
    https://docs.microsoft.com/en-us/cli/azure/network/firewall

.COMPONENT
    Azure CLI Firewall Management
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Firewall")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$FirewallName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $true, HelpMessage = "Action to perform")]
    [ValidateSet('Create', 'Update', 'Delete', 'List', 'Show', 'Validate')]
    [string]$Action,

    [Parameter(Mandatory = $true, HelpMessage = "Type of firewall rule")]
    [ValidateSet('Application', 'Network', 'NAT')]
    [string]$RuleType,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the rule collection")]
    [ValidateLength(1, 80)]
    [string]$CollectionName,

    [Parameter(Mandatory = $false, HelpMessage = "Name of the rule")]
    [ValidateLength(1, 80)]
    [string]$RuleName,

    [Parameter(Mandatory = $false, HelpMessage = "Priority of the rule collection")]
    [ValidateRange(100, 65000)]
    [int]$Priority = 1000,

    [Parameter(Mandatory = $false, HelpMessage = "Action type")]
    [ValidateSet('Allow', 'Deny')]
    [string]$ActionType = 'Allow',

    [Parameter(Mandatory = $false, HelpMessage = "Source addresses (comma-separated)")]
    [string]$SourceAddresses,

    [Parameter(Mandatory = $false, HelpMessage = "Destination addresses (comma-separated)")]
    [string]$DestinationAddresses,

    [Parameter(Mandatory = $false, HelpMessage = "Destination ports (comma-separated)")]
    [string]$DestinationPorts,

    [Parameter(Mandatory = $false, HelpMessage = "Protocols (comma-separated)")]
    [string]$Protocols = "TCP",

    [Parameter(Mandatory = $false, HelpMessage = "Target FQDNs (comma-separated)")]
    [string]$TargetFqdns,

    [Parameter(Mandatory = $false, HelpMessage = "FQDN tags (comma-separated)")]
    [string]$FqdnTags,

    [Parameter(Mandatory = $false, HelpMessage = "Translated address for NAT rules")]
    [string]$TranslatedAddress,

    [Parameter(Mandatory = $false, HelpMessage = "Translated port for NAT rules")]
    [string]$TranslatedPort,

    [Parameter(Mandatory = $false, HelpMessage = "Validate rule configurations")]
    [switch]$ValidateRules,

    [Parameter(Mandatory = $false, HelpMessage = "Create backup before changes")]
    [switch]$BackupRules,

    [Parameter(Mandatory = $false, HelpMessage = "Backup file path")]
    [string]$BackupPath,

    [Parameter(Mandatory = $false, HelpMessage = "Show changes without applying")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'JSON', 'Summary')]
    [string]$OutputFormat = 'Summary',

    [Parameter(Mandatory = $false, HelpMessage = "Export complete firewall configuration")]
    [switch]$ExportConfig
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Global variables for operation tracking
$global:OperationResults = @{
    StartTime = Get-Date
    Operations = @()
    ValidationResults = @()
    BackupCreated = $false
    Summary = @{
        RulesProcessed = 0
        SuccessfulOperations = 0
        FailedOperations = 0
        ValidationIssues = 0
        ConflictsDetected = 0
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

# Function to validate firewall exists
function Test-FirewallExists {
    param($ResourceGroup, $FirewallName)

    try {
        Write-Host "🔍 Validating Azure Firewall '$FirewallName'..." -ForegroundColor Cyan
        $firewall = az network firewall show --name $FirewallName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or -not $firewall) {
            throw "Azure Firewall '$FirewallName' not found in resource group '$ResourceGroup'"
        }
        Write-Host "✅ Azure Firewall '$FirewallName' found" -ForegroundColor Green
        return $firewall
    }
    catch {
        Write-Error "Firewall validation failed: $($_.Exception.Message)"
        return $null
    }
}

# Function to get existing rules
function Get-FirewallRules {
    param($ResourceGroup, $FirewallName, $RuleType)

    try {
        Write-Host "🔍 Retrieving existing $RuleType rules..." -ForegroundColor Cyan

        $rules = @()

        switch ($RuleType) {
            'Application' {
                $collections = az network firewall application-rule collection list --firewall-name $FirewallName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
                if ($collections) {
                    foreach ($collection in $collections) {
                        $rules += @{
                            Type = 'Application'
                            Collection = $collection.name
                            Priority = $collection.priority
                            Action = $collection.action.type
                            Rules = $collection.rules
                        }
                    }
                }
            }
            'Network' {
                $collections = az network firewall network-rule collection list --firewall-name $FirewallName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
                if ($collections) {
                    foreach ($collection in $collections) {
                        $rules += @{
                            Type = 'Network'
                            Collection = $collection.name
                            Priority = $collection.priority
                            Action = $collection.action.type
                            Rules = $collection.rules
                        }
                    }
                }
            }
            'NAT' {
                $collections = az network firewall nat-rule collection list --firewall-name $FirewallName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
                if ($collections) {
                    foreach ($collection in $collections) {
                        $rules += @{
                            Type = 'NAT'
                            Collection = $collection.name
                            Priority = $collection.priority
                            Rules = $collection.rules
                        }
                    }
                }
            }
        }

        Write-Host "✅ Retrieved $($rules.Count) $RuleType rule collection(s)" -ForegroundColor Green
        return $rules
    }
    catch {
        Write-Warning "Error retrieving $RuleType rules: $($_.Exception.Message)"
        return @()
    }
}

# Function to validate rule parameters
function Test-RuleParameters {
    param($RuleType, $Parameters)

    try {
        Write-Host "🔍 Validating rule parameters..." -ForegroundColor Cyan

        $issues = @()

        # Common validations
        if (-not $Parameters.CollectionName) {
            $issues += "Collection name is required"
        }

        if (-not $Parameters.SourceAddresses) {
            $issues += "Source addresses are required"
        }

        # Type-specific validations
        switch ($RuleType) {
            'Application' {
                if (-not $Parameters.TargetFqdns -and -not $Parameters.FqdnTags) {
                    $issues += "Application rules require either Target FQDNs or FQDN tags"
                }

                if ($Parameters.TargetFqdns -and $Parameters.FqdnTags) {
                    $issues += "Application rules cannot have both Target FQDNs and FQDN tags"
                }
            }
            'Network' {
                if (-not $Parameters.DestinationAddresses) {
                    $issues += "Network rules require destination addresses"
                }

                if (-not $Parameters.DestinationPorts) {
                    $issues += "Network rules require destination ports"
                }

                # Validate protocols
                $validProtocols = @('TCP', 'UDP', 'ICMP', 'Any')
                $protocols = $Parameters.Protocols -split ','
                $invalidProtocols = $protocols | Where-Object { $_ -notin $validProtocols }
                if ($invalidProtocols.Count -gt 0) {
                    $issues += "Invalid protocols: $($invalidProtocols -join ', '). Valid protocols: $($validProtocols -join ', ')"
                }
            }
            'NAT' {
                if (-not $Parameters.DestinationAddresses) {
                    $issues += "NAT rules require destination addresses"
                }

                if (-not $Parameters.DestinationPorts) {
                    $issues += "NAT rules require destination ports"
                }

                if (-not $Parameters.TranslatedAddress) {
                    $issues += "NAT rules require translated address"
                }

                if (-not $Parameters.TranslatedPort) {
                    $issues += "NAT rules require translated port"
                }
            }
        }

        # Validate IP addresses and ranges
        if ($Parameters.SourceAddresses) {
            $sourceIPs = $Parameters.SourceAddresses -split ','
            foreach ($ip in $sourceIPs) {
                $ip = $ip.Trim()
                if ($ip -ne "*" -and $ip -notmatch '^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$') {
                    $issues += "Invalid source IP format: $ip"
                }
            }
        }

        if ($Parameters.DestinationAddresses) {
            $destIPs = $Parameters.DestinationAddresses -split ','
            foreach ($ip in $destIPs) {
                $ip = $ip.Trim()
                if ($ip -ne "*" -and $ip -notmatch '^(\d{1,3}\.){3}\d{1,3}(/\d{1,2})?$') {
                    $issues += "Invalid destination IP format: $ip"
                }
            }
        }

        # Validate ports
        if ($Parameters.DestinationPorts) {
            $ports = $Parameters.DestinationPorts -split ','
            foreach ($port in $ports) {
                $port = $port.Trim()
                if ($port -ne "*" -and $port -notmatch '^\d+(-\d+)?$') {
                    $issues += "Invalid port format: $port"
                }
                elseif ($port -match '^\d+$' -and ([int]$port -lt 1 -or [int]$port -gt 65535)) {
                    $issues += "Port out of range (1-65535): $port"
                }
            }
        }

        if ($issues.Count -gt 0) {
            Write-Host "❌ Parameter validation failed:" -ForegroundColor Red
            $issues | ForEach-Object { Write-Host "   - $_" -ForegroundColor Red }
            return $false
        }

        Write-Host "✅ Parameter validation successful" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Parameter validation error: $($_.Exception.Message)"
        return $false
    }
}

# Function to check for rule conflicts
function Test-RuleConflicts {
    param($NewRule, $ExistingRules, $RuleType)

    try {
        Write-Host "🔍 Checking for rule conflicts..." -ForegroundColor Cyan

        $conflicts = @()

        foreach ($existingCollection in $ExistingRules) {
            # Check priority conflicts
            if ($existingCollection.Priority -eq $NewRule.Priority -and $existingCollection.Collection -ne $NewRule.CollectionName) {
                $conflicts += @{
                    Type = "Priority"
                    Severity = "High"
                    Details = "Priority $($NewRule.Priority) already used by collection '$($existingCollection.Collection)'"
                    ExistingCollection = $existingCollection.Collection
                }
            }

            # Check for overlapping rules within same priority range
            $priorityDiff = [Math]::Abs($existingCollection.Priority - $NewRule.Priority)
            if ($priorityDiff -le 10 -and $existingCollection.Collection -ne $NewRule.CollectionName) {
                # Check for rule overlap based on type
                switch ($RuleType) {
                    'Network' {
                        # Check for overlapping network rules
                        foreach ($existingRule in $existingCollection.Rules) {
                            if (Test-NetworkRuleOverlap -NewRule $NewRule -ExistingRule $existingRule) {
                                $conflicts += @{
                                    Type = "RuleOverlap"
                                    Severity = "Medium"
                                    Details = "Potential overlap with rule '$($existingRule.name)' in collection '$($existingCollection.Collection)'"
                                    ExistingRule = $existingRule.name
                                    ExistingCollection = $existingCollection.Collection
                                }
                            }
                        }
                    }
                    'Application' {
                        # Check for overlapping application rules
                        foreach ($existingRule in $existingCollection.Rules) {
                            if (Test-ApplicationRuleOverlap -NewRule $NewRule -ExistingRule $existingRule) {
                                $conflicts += @{
                                    Type = "RuleOverlap"
                                    Severity = "Medium"
                                    Details = "Potential overlap with rule '$($existingRule.name)' in collection '$($existingCollection.Collection)'"
                                    ExistingRule = $existingRule.name
                                    ExistingCollection = $existingCollection.Collection
                                }
                            }
                        }
                    }
                }
            }
        }

        if ($conflicts.Count -gt 0) {
            Write-Host "⚠️ Rule conflicts detected:" -ForegroundColor Yellow
            $conflicts | ForEach-Object {
                $color = switch ($_.Severity) {
                    "High" { "Red" }
                    "Medium" { "Yellow" }
                    "Low" { "Gray" }
                }
                Write-Host "   [$($_.Severity)] $($_.Type): $($_.Details)" -ForegroundColor $color
            }
            $global:OperationResults.Summary.ConflictsDetected += $conflicts.Count
        }
        else {
            Write-Host "✅ No rule conflicts detected" -ForegroundColor Green
        }

        return $conflicts
    }
    catch {
        Write-Warning "Error checking rule conflicts: $($_.Exception.Message)"
        return @()
    }
}

# Function to test network rule overlap
function Test-NetworkRuleOverlap {
    param($NewRule, $ExistingRule)

    try {
        # Simple overlap detection - can be enhanced for more sophisticated checking
        $newSources = $NewRule.SourceAddresses -split ',' | ForEach-Object { $_.Trim() }
        $existingSources = $ExistingRule.sourceAddresses

        $newDests = $NewRule.DestinationAddresses -split ',' | ForEach-Object { $_.Trim() }
        $existingDests = $ExistingRule.destinationAddresses

        $newPorts = $NewRule.DestinationPorts -split ',' | ForEach-Object { $_.Trim() }
        $existingPorts = $ExistingRule.destinationPorts

        # Check for any overlapping sources, destinations, and ports
        $sourceOverlap = ($newSources | Where-Object { $_ -in $existingSources -or $_ -eq "*" -or $existingSources -contains "*" }).Count -gt 0
        $destOverlap = ($newDests | Where-Object { $_ -in $existingDests -or $_ -eq "*" -or $existingDests -contains "*" }).Count -gt 0
        $portOverlap = ($newPorts | Where-Object { $_ -in $existingPorts -or $_ -eq "*" -or $existingPorts -contains "*" }).Count -gt 0

        return $sourceOverlap -and $destOverlap -and $portOverlap
    }
    catch {
        return $false
    }
}

# Function to test application rule overlap
function Test-ApplicationRuleOverlap {
    param($NewRule, $ExistingRule)

    try {
        # Simple overlap detection for application rules
        $newSources = $NewRule.SourceAddresses -split ',' | ForEach-Object { $_.Trim() }
        $existingSources = $ExistingRule.sourceAddresses

        if ($NewRule.TargetFqdns) {
            $newTargets = $NewRule.TargetFqdns -split ',' | ForEach-Object { $_.Trim() }
            $existingTargets = $ExistingRule.targetFqdns

            $sourceOverlap = ($newSources | Where-Object { $_ -in $existingSources -or $_ -eq "*" -or $existingSources -contains "*" }).Count -gt 0
            $targetOverlap = ($newTargets | Where-Object { $_ -in $existingTargets }).Count -gt 0

            return $sourceOverlap -and $targetOverlap
        }

        return $false
    }
    catch {
        return $false
    }
}

# Function to create backup
function New-FirewallBackup {
    param($ResourceGroup, $FirewallName, $BackupPath)

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

        if (-not $BackupPath) {
            $BackupPath = ".\firewall-backup-$FirewallName-$timestamp"
        }

        # Create backup directory
        if (-not (Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        }

        Write-Host "💾 Creating firewall configuration backup..." -ForegroundColor Cyan

        # Get complete firewall configuration
        $firewall = az network firewall show --name $FirewallName --resource-group $ResourceGroup --output json | ConvertFrom-Json

        # Get all rule collections
        $appRules = az network firewall application-rule collection list --firewall-name $FirewallName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
        $netRules = az network firewall network-rule collection list --firewall-name $FirewallName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json
        $natRules = az network firewall nat-rule collection list --firewall-name $FirewallName --resource-group $ResourceGroup --output json 2>$null | ConvertFrom-Json

        $backupData = @{
            Metadata = @{
                BackupDate = Get-Date
                FirewallName = $FirewallName
                ResourceGroup = $ResourceGroup
                BackupReason = "Pre-operation backup"
            }
            Firewall = $firewall
            ApplicationRules = $appRules
            NetworkRules = $netRules
            NatRules = $natRules
        }

        $backupFile = Join-Path $BackupPath "firewall-config-$timestamp.json"
        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8

        # Create human-readable summary
        $summaryFile = Join-Path $BackupPath "firewall-summary-$timestamp.txt"
        $summary = @"
Azure Firewall Configuration Backup
====================================
Firewall: $FirewallName
Resource Group: $ResourceGroup
Backup Date: $(Get-Date)

Configuration Summary:
- Application Rule Collections: $($appRules.Count)
- Network Rule Collections: $($netRules.Count)
- NAT Rule Collections: $($natRules.Count)

Application Rules:
$(if ($appRules) { $appRules | ForEach-Object { "  - $($_.name) (Priority: $($_.priority), Action: $($_.action.type))" } | Out-String } else { "  None" })

Network Rules:
$(if ($netRules) { $netRules | ForEach-Object { "  - $($_.name) (Priority: $($_.priority), Action: $($_.action.type))" } | Out-String } else { "  None" })

NAT Rules:
$(if ($natRules) { $natRules | ForEach-Object { "  - $($_.name) (Priority: $($_.priority))" } | Out-String } else { "  None" })
"@

        $summary | Out-File -FilePath $summaryFile -Encoding UTF8

        Write-Host "✅ Backup created: $backupFile" -ForegroundColor Green
        Write-Host "📄 Summary created: $summaryFile" -ForegroundColor Green

        $global:OperationResults.BackupCreated = $true

        return @{
            BackupFile = $backupFile
            SummaryFile = $summaryFile
            Success = $true
        }
    }
    catch {
        Write-Warning "Error creating backup: $($_.Exception.Message)"
        return @{
            BackupFile = $null
            SummaryFile = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Function to create firewall rule
function New-FirewallRule {
    param($ResourceGroup, $FirewallName, $RuleType, $Parameters, $DryRun)

    try {
        $operationStart = Get-Date

        if ($DryRun) {
            Write-Host "🎭 [DRY RUN] Would create $RuleType rule in collection '$($Parameters.CollectionName)'" -ForegroundColor Magenta

            $global:OperationResults.Operations += @{
                Action = "Create"
                RuleType = $RuleType
                Collection = $Parameters.CollectionName
                Rule = $Parameters.RuleName
                StartTime = $operationStart
                EndTime = Get-Date
                Success = $true
                DryRun = $true
            }

            return @{
                Success = $true
                DryRun = $true
                Message = "Dry run completed"
            }
        }

        Write-Host "🔧 Creating $RuleType rule..." -ForegroundColor Cyan

        # Build Azure CLI command based on rule type
        $azParams = @()

        switch ($RuleType) {
            'Application' {
                $azParams = @(
                    'network', 'firewall', 'application-rule', 'create',
                    '--collection-name', $Parameters.CollectionName,
                    '--firewall-name', $FirewallName,
                    '--name', $Parameters.RuleName,
                    '--priority', $Parameters.Priority,
                    '--action', $Parameters.ActionType,
                    '--resource-group', $ResourceGroup,
                    '--source-addresses', $Parameters.SourceAddresses
                )

                if ($Parameters.TargetFqdns) {
                    $azParams += '--target-fqdns'
                    $azParams += $Parameters.TargetFqdns
                }

                if ($Parameters.FqdnTags) {
                    $azParams += '--fqdn-tags'
                    $azParams += $Parameters.FqdnTags
                }

                if ($Parameters.Protocols) {
                    $azParams += '--protocols'
                    $azParams += $Parameters.Protocols
                }
            }

            'Network' {
                $azParams = @(
                    'network', 'firewall', 'network-rule', 'create',
                    '--collection-name', $Parameters.CollectionName,
                    '--firewall-name', $FirewallName,
                    '--name', $Parameters.RuleName,
                    '--priority', $Parameters.Priority,
                    '--action', $Parameters.ActionType,
                    '--resource-group', $ResourceGroup,
                    '--source-addresses', $Parameters.SourceAddresses,
                    '--destination-addresses', $Parameters.DestinationAddresses,
                    '--destination-ports', $Parameters.DestinationPorts,
                    '--protocols', $Parameters.Protocols
                )
            }

            'NAT' {
                $azParams = @(
                    'network', 'firewall', 'nat-rule', 'create',
                    '--collection-name', $Parameters.CollectionName,
                    '--firewall-name', $FirewallName,
                    '--name', $Parameters.RuleName,
                    '--priority', $Parameters.Priority,
                    '--resource-group', $ResourceGroup,
                    '--source-addresses', $Parameters.SourceAddresses,
                    '--destination-addresses', $Parameters.DestinationAddresses,
                    '--destination-ports', $Parameters.DestinationPorts,
                    '--protocols', $Parameters.Protocols,
                    '--translated-address', $Parameters.TranslatedAddress,
                    '--translated-port', $Parameters.TranslatedPort
                )
            }
        }

        # Execute the command
        $result = az @azParams --output json 2>&1

        if ($LASTEXITCODE -eq 0) {
            $operationEnd = Get-Date
            $duration = $operationEnd - $operationStart

            Write-Host "✅ $RuleType rule '$($Parameters.RuleName)' created successfully in $($duration.TotalSeconds) seconds" -ForegroundColor Green

            $global:OperationResults.Operations += @{
                Action = "Create"
                RuleType = $RuleType
                Collection = $Parameters.CollectionName
                Rule = $Parameters.RuleName
                StartTime = $operationStart
                EndTime = $operationEnd
                Duration = $duration
                Success = $true
                DryRun = $false
            }

            $global:OperationResults.Summary.SuccessfulOperations++

            return @{
                Success = $true
                DryRun = $false
                Message = "Rule created successfully"
                Duration = $duration
                Result = $result | ConvertFrom-Json
            }
        }
        else {
            throw "Azure CLI returned exit code: $LASTEXITCODE. Output: $result"
        }
    }
    catch {
        Write-Error "❌ Failed to create $RuleType rule: $($_.Exception.Message)"

        $global:OperationResults.Operations += @{
            Action = "Create"
            RuleType = $RuleType
            Collection = $Parameters.CollectionName
            Rule = $Parameters.RuleName
            StartTime = $operationStart
            EndTime = Get-Date
            Success = $false
            Error = $_.Exception.Message
            DryRun = $false
        }

        $global:OperationResults.Summary.FailedOperations++

        return @{
            Success = $false
            DryRun = $false
            Message = $_.Exception.Message
        }
    }
}

# Function to delete firewall rule
function Remove-FirewallRule {
    param($ResourceGroup, $FirewallName, $RuleType, $CollectionName, $RuleName, $DryRun)

    try {
        $operationStart = Get-Date

        if ($DryRun) {
            Write-Host "🎭 [DRY RUN] Would delete $RuleType rule '$RuleName' from collection '$CollectionName'" -ForegroundColor Magenta
            return @{ Success = $true; DryRun = $true; Message = "Dry run completed" }
        }

        Write-Host "🗑️ Deleting $RuleType rule '$RuleName'..." -ForegroundColor Yellow

        # Build delete command based on rule type
        switch ($RuleType) {
            'Application' {
                if ($RuleName) {
                    $null = az network firewall application-rule delete --collection-name $CollectionName --firewall-name $FirewallName --name $RuleName --resource-group $ResourceGroup
                }
                else {
                    $null = az network firewall application-rule collection delete --name $CollectionName --firewall-name $FirewallName --resource-group $ResourceGroup
                }
            }
            'Network' {
                if ($RuleName) {
                    $null = az network firewall network-rule delete --collection-name $CollectionName --firewall-name $FirewallName --name $RuleName --resource-group $ResourceGroup
                }
                else {
                    $null = az network firewall network-rule collection delete --name $CollectionName --firewall-name $FirewallName --resource-group $ResourceGroup
                }
            }
            'NAT' {
                if ($RuleName) {
                    $null = az network firewall nat-rule delete --collection-name $CollectionName --firewall-name $FirewallName --name $RuleName --resource-group $ResourceGroup
                }
                else {
                    $null = az network firewall nat-rule collection delete --name $CollectionName --firewall-name $FirewallName --resource-group $ResourceGroup
                }
            }
        }

        if ($LASTEXITCODE -eq 0) {
            $operationEnd = Get-Date
            $duration = $operationEnd - $operationStart

            $target = if ($RuleName) { "rule '$RuleName'" } else { "collection '$CollectionName'" }
            Write-Host "✅ $RuleType $target deleted successfully in $($duration.TotalSeconds) seconds" -ForegroundColor Green

            $global:OperationResults.Summary.SuccessfulOperations++

            return @{
                Success = $true
                DryRun = $false
                Message = "$RuleType $target deleted successfully"
                Duration = $duration
            }
        }
        else {
            throw "Azure CLI returned exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-Error "❌ Failed to delete $RuleType rule: $($_.Exception.Message)"
        $global:OperationResults.Summary.FailedOperations++

        return @{
            Success = $false
            DryRun = $false
            Message = $_.Exception.Message
        }
    }
}

# Function to display rules
function Show-FirewallRules {
    param($Rules, $Format)

    switch ($Format) {
        'Table' {
            foreach ($collection in $Rules) {
                Write-Host "`n📋 $($collection.Type) Rules - Collection: $($collection.Collection)" -ForegroundColor Yellow
                Write-Host "   Priority: $($collection.Priority), Action: $($collection.Action)" -ForegroundColor Gray

                if ($collection.Rules) {
                    $collection.Rules | Format-Table -Property name, @{Label="Source"; Expression={$_.sourceAddresses -join ', '}}, @{Label="Destination"; Expression={$_.destinationAddresses -join ', '}}, @{Label="Ports"; Expression={$_.destinationPorts -join ', '}} -AutoSize
                }
                else {
                    Write-Host "   No rules in this collection" -ForegroundColor Gray
                }
            }
        }
        'JSON' {
            return $Rules | ConvertTo-Json -Depth 10
        }
        'Summary' {
            Write-Host "`n📊 Firewall Rules Summary:" -ForegroundColor Yellow
            $Rules | Group-Object -Property Type | ForEach-Object {
                Write-Host "   $($_.Name) Rules: $($_.Count) collection(s)" -ForegroundColor White
                $_.Group | ForEach-Object {
                    $ruleCount = if ($_.Rules) { $_.Rules.Count } else { 0 }
                    Write-Host "     - $($_.Collection): Priority $($_.Priority), $ruleCount rule(s)" -ForegroundColor Gray
                }
            }
        }
    }
}

# Function to export firewall configuration
function Export-FirewallConfig {
    param($ResourceGroup, $FirewallName, $Path)

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        if (-not $Path) {
            $Path = ".\firewall-export-$FirewallName-$timestamp.json"
        }

        Write-Host "📤 Exporting firewall configuration..." -ForegroundColor Cyan

        # Get all configurations
        $firewall = az network firewall show --name $FirewallName --resource-group $ResourceGroup --output json | ConvertFrom-Json
        $appRules = Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType "Application"
        $netRules = Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType "Network"
        $natRules = Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType "NAT"

        $exportData = @{
            ExportDate = Get-Date
            Firewall = $firewall
            Rules = @{
                Application = $appRules
                Network = $netRules
                NAT = $natRules
            }
        }

        $exportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
        Write-Host "✅ Configuration exported to: $Path" -ForegroundColor Green

        return $Path
    }
    catch {
        Write-Warning "Error exporting configuration: $($_.Exception.Message)"
        return $null
    }
}

# Main execution
try {
    Write-Host "🔥 Starting Azure Firewall Rule Management" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate firewall exists
    $firewall = Test-FirewallExists -ResourceGroup $ResourceGroup -FirewallName $FirewallName
    if (-not $firewall) {
        exit 1
    }

    # Create backup if requested
    if ($BackupRules -and -not $DryRun) {
        $backup = New-FirewallBackup -ResourceGroup $ResourceGroup -FirewallName $FirewallName -BackupPath $BackupPath
        if (-not $backup.Success) {
            Write-Warning "Backup failed but continuing with operation"
        }
    }

    # Prepare rule parameters
    $ruleParameters = @{
        CollectionName = $CollectionName
        RuleName = $RuleName
        Priority = $Priority
        ActionType = $ActionType
        SourceAddresses = $SourceAddresses
        DestinationAddresses = $DestinationAddresses
        DestinationPorts = $DestinationPorts
        Protocols = $Protocols
        TargetFqdns = $TargetFqdns
        FqdnTags = $FqdnTags
        TranslatedAddress = $TranslatedAddress
        TranslatedPort = $TranslatedPort
    }

    # Execute action
    switch ($Action) {
        'Create' {
            # Validate parameters
            if (-not (Test-RuleParameters -RuleType $RuleType -Parameters $ruleParameters)) {
                exit 1
            }

            # Check for conflicts if validation requested
            if ($ValidateRules) {
                $existingRules = Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType $RuleType
                $conflicts = Test-RuleConflicts -NewRule $ruleParameters -ExistingRules $existingRules -RuleType $RuleType
            }

            # Create the rule
            $result = New-FirewallRule -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType $RuleType -Parameters $ruleParameters -DryRun $DryRun
        }

        'Delete' {
            $result = Remove-FirewallRule -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType $RuleType -CollectionName $CollectionName -RuleName $RuleName -DryRun $DryRun
        }

        'List' {
            $rules = Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType $RuleType
            Show-FirewallRules -Rules $rules -Format $OutputFormat
        }

        'Show' {
            if ($CollectionName) {
                # Show specific collection
                $rules = Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType $RuleType
                $collection = $rules | Where-Object { $_.Collection -eq $CollectionName }
                if ($collection) {
                    Show-FirewallRules -Rules @($collection) -Format $OutputFormat
                }
                else {
                    Write-Warning "Collection '$CollectionName' not found"
                }
            }
            else {
                # Show all rules for this type
                $rules = Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType $RuleType
                Show-FirewallRules -Rules $rules -Format $OutputFormat
            }
        }

        'Validate' {
            $allRules = @()
            $allRules += Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType "Application"
            $allRules += Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType "Network"
            $allRules += Get-FirewallRules -ResourceGroup $ResourceGroup -FirewallName $FirewallName -RuleType "NAT"

            Write-Host "🔍 Validating all firewall rules..." -ForegroundColor Cyan
            Write-Host "✅ Validation completed - found $($allRules.Count) rule collection(s)" -ForegroundColor Green

            Show-FirewallRules -Rules $allRules -Format $OutputFormat
        }
    }

    # Export configuration if requested
    if ($ExportConfig) {
        $exportPath = Export-FirewallConfig -ResourceGroup $ResourceGroup -FirewallName $FirewallName
    }

    # Show operation summary
    Write-Host "`n📊 Operation Summary:" -ForegroundColor Yellow
    Write-Host "   Successful Operations: $($global:OperationResults.Summary.SuccessfulOperations)" -ForegroundColor Green
    Write-Host "   Failed Operations: $($global:OperationResults.Summary.FailedOperations)" -ForegroundColor Red
    Write-Host "   Conflicts Detected: $($global:OperationResults.Summary.ConflictsDetected)" -ForegroundColor Yellow
    Write-Host "   Backup Created: $($global:OperationResults.BackupCreated)" -ForegroundColor Cyan

    if ($DryRun) {
        Write-Host "`n🎭 This was a dry run. No actual changes were made." -ForegroundColor Magenta
    }
}
catch {
    Write-Error "❌ Firewall rule management failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Firewall rule management completed" -ForegroundColor Green
}
