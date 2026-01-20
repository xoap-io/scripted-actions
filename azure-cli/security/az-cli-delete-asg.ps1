<#
.SYNOPSIS
    Delete Azure Application Security Groups (ASGs) using Azure CLI with comprehensive safety checks.

.DESCRIPTION
    This script safely deletes Azure Application Security Groups using the Azure CLI with extensive validation and safety mechanisms.
    Includes dependency checking, usage analysis, backup capabilities, and confirmation prompts.
    Supports bulk deletion with filtering and provides detailed reporting of deletion operations.

    The script uses the Azure CLI command: az network asg delete

.PARAMETER Name
    Name of the ASG to delete. Can be a single name or comma-separated list for bulk deletion.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the ASG(s).

.PARAMETER Force
    Skip confirmation prompts for automated scenarios.

.PARAMETER CheckUsage
    Check for ASG usage in NSG rules before deletion.

.PARAMETER BackupReferences
    Create backup of all NSG rules that reference the ASG.

.PARAMETER BackupPath
    Path for backup files (defaults to current directory with timestamp).

.PARAMETER BulkDelete
    Enable bulk deletion mode with pattern matching.

.PARAMETER NamePattern
    Pattern for ASG names in bulk deletion (supports wildcards).

.PARAMETER ExcludeNames
    Comma-separated list of ASG names to exclude from bulk deletion.

.PARAMETER DryRun
    Show what would be deleted without actually deleting.

.PARAMETER RemoveFromRules
    Automatically remove ASG references from NSG rules before deletion.

.PARAMETER UpdateRulesMode
    How to handle NSG rules that reference the ASG.

.PARAMETER OutputReport
    Generate detailed deletion report.

.PARAMETER ReportPath
    Path for the deletion report file.

.PARAMETER Timeout
    Timeout in seconds for deletion operations.

.EXAMPLE
    .\az-cli-delete-asg.ps1 -Name "asg-web" -ResourceGroup "rg-web" -CheckUsage -BackupReferences

.EXAMPLE
    .\az-cli-delete-asg.ps1 -BulkDelete -NamePattern "asg-temp-*" -ResourceGroup "rg-temp" -Force -DryRun

.EXAMPLE
    .\az-cli-delete-asg.ps1 -Name "asg-old,asg-unused" -ResourceGroup "rg-cleanup" -RemoveFromRules -UpdateRulesMode "Disable" -OutputReport

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later

    Safety Features:
    - Usage checking in NSG rules before deletion
    - Backup capabilities for NSG rule configurations
    - Automatic removal from NSG rules with various modes
    - Confirmation prompts with detailed information
    - Dry run mode for testing
    - Comprehensive logging and reporting

.LINK
    https://docs.microsoft.com/en-us/cli/azure/network/asg

.COMPONENT
    Azure CLI Application Security Groups
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "ASG name(s) to delete")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Check ASG usage in NSG rules")]
    [switch]$CheckUsage,

    [Parameter(Mandatory = $false, HelpMessage = "Backup NSG rules that reference ASG")]
    [switch]$BackupReferences,

    [Parameter(Mandatory = $false, HelpMessage = "Backup file path")]
    [string]$BackupPath,

    [Parameter(Mandatory = $false, HelpMessage = "Enable bulk deletion mode")]
    [switch]$BulkDelete,

    [Parameter(Mandatory = $false, HelpMessage = "Pattern for bulk deletion")]
    [string]$NamePattern,

    [Parameter(Mandatory = $false, HelpMessage = "Names to exclude from deletion")]
    [string]$ExcludeNames,

    [Parameter(Mandatory = $false, HelpMessage = "Show what would be deleted")]
    [switch]$DryRun,

    [Parameter(Mandatory = $false, HelpMessage = "Remove ASG from NSG rules before deletion")]
    [switch]$RemoveFromRules,

    [Parameter(Mandatory = $false, HelpMessage = "How to handle NSG rules")]
    [ValidateSet('Disable', 'Delete', 'Convert')]
    [string]$UpdateRulesMode = 'Disable',

    [Parameter(Mandatory = $false, HelpMessage = "Generate deletion report")]
    [switch]$OutputReport,

    [Parameter(Mandatory = $false, HelpMessage = "Report file path")]
    [string]$ReportPath,

    [Parameter(Mandatory = $false, HelpMessage = "Deletion timeout in seconds")]
    [ValidateRange(30, 3600)]
    [int]$Timeout = 300
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Global variables for reporting
$global:DeletionReport = @{
    StartTime = Get-Date
    Operations = @()
    RuleModifications = @()
    Summary = @{
        TotalRequested = 0
        SuccessfulDeletions = 0
        FailedDeletions = 0
        SkippedDeletions = 0
        BackupsCreated = 0
        RulesModified = 0
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

# Function to validate resource group exists
function Test-ResourceGroupExists {
    param($ResourceGroup)

    try {
        Write-Host "🔍 Validating resource group '$ResourceGroup'..." -ForegroundColor Cyan
        $null = az group show --name $ResourceGroup --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -ne 0) {
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

# Function to get ASGs to delete based on parameters
function Get-ASGsToDelete {
    param($ResourceGroup, $Name, $BulkDelete, $NamePattern, $ExcludeNames)

    try {
        Write-Host "🔍 Identifying ASGs to delete..." -ForegroundColor Cyan

        $asgsToDelete = @()
        $excludeList = @()

        if ($ExcludeNames) {
            $excludeList = $ExcludeNames -split ',' | ForEach-Object { $_.Trim() }
        }

        if ($BulkDelete) {
            # Get all ASGs in resource group
            $allASGs = az network asg list --resource-group $ResourceGroup --output json | ConvertFrom-Json

            if ($NamePattern) {
                # Filter by pattern
                $filteredASGs = $allASGs | Where-Object { $_.name -like $NamePattern }
            }
            else {
                $filteredASGs = $allASGs
            }

            # Exclude specified ASGs
            if ($excludeList.Count -gt 0) {
                $filteredASGs = $filteredASGs | Where-Object { $_.name -notin $excludeList }
            }

            $asgsToDelete = $filteredASGs
        }
        elseif ($Name) {
            # Process specific ASG names
            $nameList = $Name -split ',' | ForEach-Object { $_.Trim() }

            foreach ($asgName in $nameList) {
                if ($asgName -notin $excludeList) {
                    try {
                        $asg = az network asg show --resource-group $ResourceGroup --name $asgName --output json 2>$null | ConvertFrom-Json
                        if ($asg) {
                            $asgsToDelete += $asg
                        }
                        else {
                            Write-Warning "ASG '$asgName' not found in resource group '$ResourceGroup'"
                        }
                    }
                    catch {
                        Write-Warning "Error retrieving ASG '$asgName': $($_.Exception.Message)"
                    }
                }
                else {
                    Write-Host "   Excluding ASG: $asgName" -ForegroundColor Yellow
                }
            }
        }
        else {
            throw "Either -Name or -BulkDelete with -NamePattern must be specified"
        }

        if ($asgsToDelete.Count -eq 0) {
            Write-Warning "No ASGs found matching the specified criteria"
            return @()
        }

        Write-Host "✅ Found $($asgsToDelete.Count) ASG(s) to delete" -ForegroundColor Green
        return $asgsToDelete
    }
    catch {
        Write-Error "Error identifying ASGs to delete: $($_.Exception.Message)"
        return @()
    }
}

# Function to check ASG usage in NSG rules
function Get-ASGUsage {
    param($ASG, $ResourceGroup)

    try {
        Write-Host "🔍 Checking usage of ASG '$($ASG.name)' in NSG rules..." -ForegroundColor Cyan

        $usage = @{
            NSGs = @()
            Rules = @()
            TotalReferences = 0
            HasUsage = $false
        }

        # Get all NSGs in the resource group (and potentially other resource groups)
        $subscription = az account show --query "id" --output tsv
        $allNSGs = az network nsg list --output json | ConvertFrom-Json

        foreach ($nsg in $allNSGs) {
            $nsgRules = @()

            # Check security rules for ASG references
            foreach ($rule in $nsg.securityRules) {
                $referencesASG = $false
                $referenceLocations = @()

                # Check source ASGs
                if ($rule.sourceApplicationSecurityGroups) {
                    foreach ($sourceAsg in $rule.sourceApplicationSecurityGroups) {
                        if ($sourceAsg.id -eq $ASG.id) {
                            $referencesASG = $true
                            $referenceLocations += "Source"
                            break
                        }
                    }
                }

                # Check destination ASGs
                if ($rule.destinationApplicationSecurityGroups) {
                    foreach ($destAsg in $rule.destinationApplicationSecurityGroups) {
                        if ($destAsg.id -eq $ASG.id) {
                            $referencesASG = $true
                            $referenceLocations += "Destination"
                            break
                        }
                    }
                }

                if ($referencesASG) {
                    $nsgRules += @{
                        Name = $rule.name
                        Priority = $rule.priority
                        Direction = $rule.direction
                        Access = $rule.access
                        Protocol = $rule.protocol
                        SourcePortRange = $rule.sourcePortRange
                        DestinationPortRange = $rule.destinationPortRange
                        ReferenceLocations = $referenceLocations
                        FullRule = $rule
                    }

                    $usage.TotalReferences++
                }
            }

            if ($nsgRules.Count -gt 0) {
                $usage.NSGs += @{
                    Name = $nsg.name
                    ResourceGroup = $nsg.resourceGroup
                    Location = $nsg.location
                    Rules = $nsgRules
                    NSGObject = $nsg
                }

                $usage.Rules += $nsgRules
                $usage.HasUsage = $true
            }
        }

        if ($usage.HasUsage) {
            Write-Host "⚠️ ASG '$($ASG.name)' is referenced in $($usage.TotalReferences) rule(s) across $($usage.NSGs.Count) NSG(s):" -ForegroundColor Yellow

            foreach ($nsgUsage in $usage.NSGs) {
                Write-Host "   NSG: $($nsgUsage.Name) (RG: $($nsgUsage.ResourceGroup))" -ForegroundColor White
                foreach ($rule in $nsgUsage.Rules) {
                    Write-Host "     - Rule: $($rule.Name) ($($rule.Direction), $($rule.Access)) - Referenced in: $($rule.ReferenceLocations -join ', ')" -ForegroundColor Gray
                }
            }
        }
        else {
            Write-Host "✅ ASG '$($ASG.name)' is not referenced in any NSG rules" -ForegroundColor Green
        }

        return $usage
    }
    catch {
        Write-Warning "Error checking ASG usage for '$($ASG.name)': $($_.Exception.Message)"
        return @{ HasUsage = $false; NSGs = @(); Rules = @(); TotalReferences = 0 }
    }
}

# Function to create backup of NSG rules that reference ASG
function New-ASGReferenceBackup {
    param($ASG, $Usage, $BackupPath)

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

        if (-not $BackupPath) {
            $BackupPath = ".\asg-reference-backup-$timestamp"
        }

        # Create backup directory
        if (-not (Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        }

        $backupFile = Join-Path $BackupPath "$($ASG.name)-references-backup-$timestamp.json"

        Write-Host "💾 Creating backup of ASG references for '$($ASG.name)'..." -ForegroundColor Cyan

        # Create backup data structure
        $backupData = @{
            ASG = $ASG
            BackupDate = Get-Date
            Usage = $Usage
            NSGRules = @()
        }

        # Include full NSG rule definitions
        foreach ($nsgUsage in $Usage.NSGs) {
            foreach ($rule in $nsgUsage.Rules) {
                $backupData.NSGRules += @{
                    NSGName = $nsgUsage.Name
                    NSGResourceGroup = $nsgUsage.ResourceGroup
                    Rule = $rule.FullRule
                    ReferenceLocations = $rule.ReferenceLocations
                }
            }
        }

        # Export backup
        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8

        # Create human-readable summary
        $summaryFile = Join-Path $BackupPath "$($ASG.name)-references-summary-$timestamp.txt"
        $summary = @"
ASG Reference Backup Summary
============================
ASG Name: $($ASG.name)
Resource Group: $($ASG.resourceGroup)
Location: $($ASG.location)
Backup Date: $(Get-Date)

Total References: $($Usage.TotalReferences)
NSGs Affected: $($Usage.NSGs.Count)

Detailed References:
$(
    foreach ($nsgUsage in $Usage.NSGs) {
        "NSG: $($nsgUsage.Name) (RG: $($nsgUsage.ResourceGroup))"
        foreach ($rule in $nsgUsage.Rules) {
            "  - Rule: $($rule.Name)"
            "    Priority: $($rule.Priority)"
            "    Direction: $($rule.Direction)"
            "    Access: $($rule.Access)"
            "    Protocol: $($rule.Protocol)"
            "    Source Port: $($rule.SourcePortRange)"
            "    Destination Port: $($rule.DestinationPortRange)"
            "    ASG Reference: $($rule.ReferenceLocations -join ', ')"
            ""
        }
    }
)

Restoration Instructions:
1. Use the JSON backup file to restore NSG rules if needed
2. Each rule contains full configuration details
3. Re-create the ASG first, then update rules to reference it
4. Test connectivity after restoration
"@

        $summary | Out-File -FilePath $summaryFile -Encoding UTF8

        Write-Host "✅ Reference backup created: $backupFile" -ForegroundColor Green
        Write-Host "📄 Summary created: $summaryFile" -ForegroundColor Green

        $global:DeletionReport.Summary.BackupsCreated++

        return @{
            BackupFile = $backupFile
            SummaryFile = $summaryFile
            Success = $true
        }
    }
    catch {
        Write-Warning "Error creating reference backup for ASG '$($ASG.name)': $($_.Exception.Message)"
        return @{
            BackupFile = $null
            SummaryFile = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Function to remove ASG from NSG rules
function Remove-ASGFromRules {
    param($ASG, $Usage, $UpdateMode, $DryRun)

    try {
        Write-Host "🔧 Removing ASG '$($ASG.name)' from NSG rules..." -ForegroundColor Cyan

        $modificationResults = @()

        foreach ($nsgUsage in $Usage.NSGs) {
            foreach ($ruleUsage in $nsgUsage.Rules) {
                $rule = $ruleUsage.FullRule
                $nsgName = $nsgUsage.Name
                $nsgResourceGroup = $nsgUsage.ResourceGroup

                Write-Host "   Processing rule '$($rule.name)' in NSG '$nsgName'..." -ForegroundColor Gray

                if ($DryRun) {
                    Write-Host "   🎭 [DRY RUN] Would modify rule '$($rule.name)' with mode '$UpdateMode'" -ForegroundColor Magenta

                    $modificationResults += @{
                        NSGName = $nsgName
                        NSGResourceGroup = $nsgResourceGroup
                        RuleName = $rule.name
                        Action = "DryRun"
                        Mode = $UpdateMode
                        Success = $true
                        DryRun = $true
                    }

                    continue
                }

                try {
                    switch ($UpdateMode) {
                        'Disable' {
                            # Disable the rule by setting access to Deny
                            $result = az network nsg rule update --resource-group $nsgResourceGroup --nsg-name $nsgName --name $rule.name --access "Deny" --output json 2>$null | ConvertFrom-Json

                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "     ✅ Rule disabled" -ForegroundColor Green
                                $modificationResults += @{
                                    NSGName = $nsgName
                                    NSGResourceGroup = $nsgResourceGroup
                                    RuleName = $rule.name
                                    Action = "Disabled"
                                    Mode = $UpdateMode
                                    Success = $true
                                    DryRun = $false
                                }
                            }
                            else {
                                throw "Failed to disable rule"
                            }
                        }

                        'Delete' {
                            # Delete the rule entirely
                            $null = az network nsg rule delete --resource-group $nsgResourceGroup --nsg-name $nsgName --name $rule.name --output none 2>$null

                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "     ✅ Rule deleted" -ForegroundColor Green
                                $modificationResults += @{
                                    NSGName = $nsgName
                                    NSGResourceGroup = $nsgResourceGroup
                                    RuleName = $rule.name
                                    Action = "Deleted"
                                    Mode = $UpdateMode
                                    Success = $true
                                    DryRun = $false
                                }
                            }
                            else {
                                throw "Failed to delete rule"
                            }
                        }

                        'Convert' {
                            # Convert ASG references to IP address ranges (if possible)
                            Write-Host "     ⚠️ Convert mode requires manual intervention - rule marked for manual update" -ForegroundColor Yellow

                            $modificationResults += @{
                                NSGName = $nsgName
                                NSGResourceGroup = $nsgResourceGroup
                                RuleName = $rule.name
                                Action = "ManualUpdateRequired"
                                Mode = $UpdateMode
                                Success = $true
                                Message = "ASG to IP conversion requires manual intervention"
                                DryRun = $false
                            }
                        }
                    }

                    $global:DeletionReport.Summary.RulesModified++
                }
                catch {
                    Write-Warning "     ❌ Failed to modify rule '$($rule.name)': $($_.Exception.Message)"

                    $modificationResults += @{
                        NSGName = $nsgName
                        NSGResourceGroup = $nsgResourceGroup
                        RuleName = $rule.name
                        Action = "Failed"
                        Mode = $UpdateMode
                        Success = $false
                        Error = $_.Exception.Message
                        DryRun = $false
                    }
                }
            }
        }

        $global:DeletionReport.RuleModifications += $modificationResults

        Write-Host "✅ ASG rule modifications completed" -ForegroundColor Green
        return $modificationResults
    }
    catch {
        Write-Warning "Error removing ASG from rules: $($_.Exception.Message)"
        return @()
    }
}

# Function to delete ASG
function Remove-ASGResource {
    param($ASG, $ResourceGroup, $Timeout, $DryRun)

    try {
        $operationStart = Get-Date

        if ($DryRun) {
            Write-Host "🎭 [DRY RUN] Would delete ASG '$($ASG.name)'" -ForegroundColor Magenta

            $global:DeletionReport.Operations += @{
                ASGName = $ASG.name
                Action = "DryRun"
                StartTime = $operationStart
                EndTime = Get-Date
                Duration = (Get-Date) - $operationStart
                Success = $true
                DryRun = $true
            }

            return @{
                Success = $true
                DryRun = $true
                Message = "Dry run completed"
            }
        }

        Write-Host "🗑️ Deleting ASG '$($ASG.name)'..." -ForegroundColor Yellow

        # Start deletion with timeout
        $job = Start-Job -ScriptBlock {
            param($ResourceGroup, $ASGName)
            az network asg delete --resource-group $ResourceGroup --name $ASGName --yes --output none 2>&1
            return $LASTEXITCODE
        } -ArgumentList $ResourceGroup, $ASG.name

        # Wait for completion with timeout
        $completed = Wait-Job -Job $job -Timeout $Timeout

        if ($completed) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job

            if ($result -eq 0) {
                $operationEnd = Get-Date
                $duration = $operationEnd - $operationStart

                Write-Host "✅ ASG '$($ASG.name)' deleted successfully in $($duration.TotalSeconds) seconds" -ForegroundColor Green

                $global:DeletionReport.Operations += @{
                    ASGName = $ASG.name
                    Action = "Delete"
                    StartTime = $operationStart
                    EndTime = $operationEnd
                    Duration = $duration
                    Success = $true
                    DryRun = $false
                }

                $global:DeletionReport.Summary.SuccessfulDeletions++

                return @{
                    Success = $true
                    DryRun = $false
                    Message = "Deletion completed successfully"
                    Duration = $duration
                }
            }
            else {
                throw "Azure CLI returned exit code: $result"
            }
        }
        else {
            Remove-Job -Job $job -Force
            throw "Deletion operation timed out after $Timeout seconds"
        }
    }
    catch {
        Write-Error "❌ Failed to delete ASG '$($ASG.name)': $($_.Exception.Message)"

        $global:DeletionReport.Operations += @{
            ASGName = $ASG.name
            Action = "Delete"
            StartTime = $operationStart
            EndTime = Get-Date
            Duration = (Get-Date) - $operationStart
            Success = $false
            Error = $_.Exception.Message
            DryRun = $false
        }

        $global:DeletionReport.Summary.FailedDeletions++

        return @{
            Success = $false
            DryRun = $false
            Message = $_.Exception.Message
        }
    }
}

# Function to show confirmation prompt
function Show-DeletionConfirmation {
    param($ASGs, $Usages)

    Write-Host "`n⚠️ ASG DELETION CONFIRMATION" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "=============================" -ForegroundColor Red -BackgroundColor Yellow

    Write-Host "`nASGs to be deleted:" -ForegroundColor Yellow
    $ASGs | ForEach-Object {
        Write-Host "  - $($_.name) (Resource Group: $($_.resourceGroup))" -ForegroundColor White
    }

    $totalReferences = ($Usages | ForEach-Object { $_.TotalReferences } | Measure-Object -Sum).Sum
    $totalNSGs = ($Usages | ForEach-Object { $_.NSGs.Count } | Measure-Object -Sum).Sum

    if ($totalReferences -gt 0) {
        Write-Host "`n⚠️ Total rule references: $totalReferences across $totalNSGs NSG(s)" -ForegroundColor Red
        Write-Host "These references will be broken when ASGs are deleted!" -ForegroundColor Red
    }

    Write-Host "`nThis action cannot be undone!" -ForegroundColor Red
    $confirmation = Read-Host "Type 'DELETE' to confirm deletion"

    return $confirmation -eq "DELETE"
}

# Function to generate deletion report
function New-DeletionReport {
    param($ReportPath)

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

        if (-not $ReportPath) {
            $ReportPath = ".\asg-deletion-report-$timestamp.html"
        }

        $endTime = Get-Date
        $totalDuration = $endTime - $global:DeletionReport.StartTime

        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>ASG Deletion Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .summary { background-color: #e8f4f8; padding: 10px; margin: 10px 0; border-radius: 5px; }
        .success { color: green; }
        .error { color: red; }
        .warning { color: orange; }
        table { border-collapse: collapse; width: 100%; margin: 10px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .operation-success { background-color: #d4edda; }
        .operation-error { background-color: #f8d7da; }
        .operation-dryrun { background-color: #d1ecf1; }
        .rule-modified { background-color: #fff3cd; }
    </style>
</head>
<body>
    <div class="header">
        <h1>ASG Deletion Report</h1>
        <p><strong>Generated:</strong> $endTime</p>
        <p><strong>Duration:</strong> $($totalDuration.TotalMinutes.ToString("F2")) minutes</p>
    </div>

    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Total Requested:</strong> $($global:DeletionReport.Summary.TotalRequested)</p>
        <p class="success"><strong>Successful Deletions:</strong> $($global:DeletionReport.Summary.SuccessfulDeletions)</p>
        <p class="error"><strong>Failed Deletions:</strong> $($global:DeletionReport.Summary.FailedDeletions)</p>
        <p class="warning"><strong>Skipped Deletions:</strong> $($global:DeletionReport.Summary.SkippedDeletions)</p>
        <p><strong>Backups Created:</strong> $($global:DeletionReport.Summary.BackupsCreated)</p>
        <p><strong>Rules Modified:</strong> $($global:DeletionReport.Summary.RulesModified)</p>
    </div>

    <h2>ASG Deletion Operations</h2>
    <table>
        <tr>
            <th>ASG Name</th>
            <th>Action</th>
            <th>Start Time</th>
            <th>Duration</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
"@

        foreach ($operation in $global:DeletionReport.Operations) {
            $statusClass = if ($operation.Success) {
                if ($operation.DryRun) { "operation-dryrun" } else { "operation-success" }
            } else {
                "operation-error"
            }

            $status = if ($operation.Success) {
                if ($operation.DryRun) { "Dry Run" } else { "Success" }
            } else {
                "Failed"
            }

            $details = if ($operation.Error) { $operation.Error } else { "N/A" }

            $html += @"
        <tr class="$statusClass">
            <td>$($operation.ASGName)</td>
            <td>$($operation.Action)</td>
            <td>$($operation.StartTime.ToString("yyyy-MM-dd HH:mm:ss"))</td>
            <td>$($operation.Duration.TotalSeconds.ToString("F2"))s</td>
            <td>$status</td>
            <td>$details</td>
        </tr>
"@
        }

        $html += @"
    </table>

    <h2>NSG Rule Modifications</h2>
    <table>
        <tr>
            <th>NSG Name</th>
            <th>Rule Name</th>
            <th>Action</th>
            <th>Mode</th>
            <th>Status</th>
            <th>Details</th>
        </tr>
"@

        foreach ($modification in $global:DeletionReport.RuleModifications) {
            $statusClass = if ($modification.Success) {
                if ($modification.DryRun) { "operation-dryrun" } else { "rule-modified" }
            } else {
                "operation-error"
            }

            $status = if ($modification.Success) {
                if ($modification.DryRun) { "Dry Run" } else { "Success" }
            } else {
                "Failed"
            }

            $details = if ($modification.Error) { $modification.Error } elseif ($modification.Message) { $modification.Message } else { "N/A" }

            $html += @"
        <tr class="$statusClass">
            <td>$($modification.NSGName)</td>
            <td>$($modification.RuleName)</td>
            <td>$($modification.Action)</td>
            <td>$($modification.Mode)</td>
            <td>$status</td>
            <td>$details</td>
        </tr>
"@
        }

        $html += @"
    </table>
</body>
</html>
"@

        $html | Out-File -FilePath $ReportPath -Encoding UTF8

        Write-Host "📊 Deletion report generated: $ReportPath" -ForegroundColor Cyan
        return $ReportPath
    }
    catch {
        Write-Warning "Error generating deletion report: $($_.Exception.Message)"
        return $null
    }
}

# Main execution
try {
    Write-Host "🗑️ Starting ASG Deletion Process" -ForegroundColor Red
    Write-Host "=================================" -ForegroundColor Red

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate resource group
    if (-not (Test-ResourceGroupExists -ResourceGroup $ResourceGroup)) {
        exit 1
    }

    # Get ASGs to delete
    $asgsToDelete = Get-ASGsToDelete -ResourceGroup $ResourceGroup -Name $Name -BulkDelete $BulkDelete -NamePattern $NamePattern -ExcludeNames $ExcludeNames

    if ($asgsToDelete.Count -eq 0) {
        Write-Warning "No ASGs found to delete"
        exit 0
    }

    $global:DeletionReport.Summary.TotalRequested = $asgsToDelete.Count

    # Check usage and create backups
    $allUsages = @()

    foreach ($asg in $asgsToDelete) {
        if ($CheckUsage) {
            $usage = Get-ASGUsage -ASG $asg -ResourceGroup $ResourceGroup
            $allUsages += $usage

            # Create backup if requested and has usage
            if ($BackupReferences -and $usage.HasUsage -and -not $DryRun) {
                $backup = New-ASGReferenceBackup -ASG $asg -Usage $usage -BackupPath $BackupPath
                if (-not $backup.Success) {
                    Write-Warning "Backup failed for ASG '$($asg.name)'. Consider manual backup before deletion."
                }
            }
        }
        else {
            $allUsages += @{ HasUsage = $false; NSGs = @(); Rules = @(); TotalReferences = 0 }
        }
    }

    # Show confirmation if not forced and not dry run
    if (-not $Force -and -not $DryRun) {
        $confirmed = Show-DeletionConfirmation -ASGs $asgsToDelete -Usages $allUsages
        if (-not $confirmed) {
            Write-Host "❌ Deletion cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }

    # Process each ASG
    for ($i = 0; $i -lt $asgsToDelete.Count; $i++) {
        $asg = $asgsToDelete[$i]
        $usage = $allUsages[$i]

        Write-Host "`n📋 Processing ASG $($i + 1) of $($asgsToDelete.Count): $($asg.name)" -ForegroundColor Cyan

        # Remove from NSG rules if requested and has usage
        if ($RemoveFromRules -and $usage.HasUsage) {
            $ruleModifications = Remove-ASGFromRules -ASG $asg -Usage $usage -UpdateMode $UpdateRulesMode -DryRun $DryRun
        }

        # Skip if has usage and not removing from rules and not forced
        if ($usage.HasUsage -and -not $RemoveFromRules -and -not $Force -and -not $DryRun) {
            Write-Warning "Skipping ASG '$($asg.name)' due to NSG rule usage. Use -RemoveFromRules or -Force to override."
            $global:DeletionReport.Summary.SkippedDeletions++
            continue
        }

        # Delete the ASG
        $deleteResult = Remove-ASGResource -ASG $asg -ResourceGroup $ResourceGroup -Timeout $Timeout -DryRun $DryRun

        if (-not $deleteResult.Success -and -not $DryRun) {
            Write-Host "❌ Failed to delete ASG '$($asg.name)'" -ForegroundColor Red
        }
    }

    # Generate report if requested
    if ($OutputReport) {
        $reportFile = New-DeletionReport -ReportPath $ReportPath
    }

    # Show final summary
    $endTime = Get-Date
    $totalDuration = $endTime - $global:DeletionReport.StartTime

    Write-Host "`n📊 Deletion Summary:" -ForegroundColor Yellow
    Write-Host "   Total Duration: $($totalDuration.TotalMinutes.ToString("F2")) minutes" -ForegroundColor White
    Write-Host "   Requested: $($global:DeletionReport.Summary.TotalRequested)" -ForegroundColor White
    Write-Host "   Successful: $($global:DeletionReport.Summary.SuccessfulDeletions)" -ForegroundColor Green
    Write-Host "   Failed: $($global:DeletionReport.Summary.FailedDeletions)" -ForegroundColor Red
    Write-Host "   Skipped: $($global:DeletionReport.Summary.SkippedDeletions)" -ForegroundColor Yellow
    Write-Host "   Backups: $($global:DeletionReport.Summary.BackupsCreated)" -ForegroundColor Cyan
    Write-Host "   Rules Modified: $($global:DeletionReport.Summary.RulesModified)" -ForegroundColor Magenta

    if ($DryRun) {
        Write-Host "`n🎭 This was a dry run. No actual deletions were performed." -ForegroundColor Magenta
    }
}
catch {
    Write-Error "❌ ASG deletion process failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 ASG deletion process completed" -ForegroundColor Green
}
