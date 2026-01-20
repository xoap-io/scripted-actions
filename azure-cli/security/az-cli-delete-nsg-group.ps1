<#
.SYNOPSIS
    Delete Azure Network Security Groups (NSGs) using Azure CLI with comprehensive safety checks.

.DESCRIPTION
    This script safely deletes Azure Network Security Groups using the Azure CLI with extensive validation and safety mechanisms.
    Includes dependency checking, backup capabilities, resource impact analysis, and confirmation prompts.
    Supports bulk deletion with filtering and provides detailed reporting of deletion operations.

    The script uses the Azure CLI command: az network nsg delete

.PARAMETER Name
    Name of the NSG to delete. Can be a single name or comma-separated list for bulk deletion.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG(s).

.PARAMETER Force
    Skip confirmation prompts for automated scenarios.

.PARAMETER BackupBeforeDelete
    Create backup of NSG rules before deletion.

.PARAMETER BackupPath
    Path for backup files (defaults to current directory with timestamp).

.PARAMETER CheckDependencies
    Check for dependent resources before deletion.

.PARAMETER AnalyzeImpact
    Analyze potential impact of NSG deletion on network traffic.

.PARAMETER BulkDelete
    Enable bulk deletion mode with pattern matching.

.PARAMETER NamePattern
    Pattern for NSG names in bulk deletion (supports wildcards).

.PARAMETER ExcludeNames
    Comma-separated list of NSG names to exclude from bulk deletion.

.PARAMETER DryRun
    Show what would be deleted without actually deleting.

.PARAMETER OutputReport
    Generate detailed deletion report.

.PARAMETER ReportPath
    Path for the deletion report file.

.PARAMETER Timeout
    Timeout in seconds for deletion operations.

.EXAMPLE
    .\az-cli-delete-nsg-group.ps1 -Name "nsg-web" -ResourceGroup "rg-web" -BackupBeforeDelete

.EXAMPLE
    .\az-cli-delete-nsg-group.ps1 -BulkDelete -NamePattern "nsg-temp-*" -ResourceGroup "rg-temp" -Force -DryRun

.EXAMPLE
    .\az-cli-delete-nsg-group.ps1 -Name "nsg-old,nsg-unused" -ResourceGroup "rg-cleanup" -CheckDependencies -AnalyzeImpact -OutputReport

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later

    Safety Features:
    - Dependency checking before deletion
    - Backup capabilities for NSG configurations
    - Impact analysis for network traffic
    - Confirmation prompts with detailed information
    - Dry run mode for testing
    - Comprehensive logging and reporting

.LINK
    https://docs.microsoft.com/en-us/cli/azure/network/nsg

.COMPONENT
    Azure CLI Network Security Groups
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "NSG name(s) to delete")]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Create backup before deletion")]
    [switch]$BackupBeforeDelete,

    [Parameter(Mandatory = $false, HelpMessage = "Backup file path")]
    [string]$BackupPath,

    [Parameter(Mandatory = $false, HelpMessage = "Check for dependent resources")]
    [switch]$CheckDependencies,

    [Parameter(Mandatory = $false, HelpMessage = "Analyze potential impact")]
    [switch]$AnalyzeImpact,

    [Parameter(Mandatory = $false, HelpMessage = "Enable bulk deletion mode")]
    [switch]$BulkDelete,

    [Parameter(Mandatory = $false, HelpMessage = "Pattern for bulk deletion")]
    [string]$NamePattern,

    [Parameter(Mandatory = $false, HelpMessage = "Names to exclude from deletion")]
    [string]$ExcludeNames,

    [Parameter(Mandatory = $false, HelpMessage = "Show what would be deleted")]
    [switch]$DryRun,

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
    Summary = @{
        TotalRequested = 0
        SuccessfulDeletions = 0
        FailedDeletions = 0
        SkippedDeletions = 0
        BackupsCreated = 0
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

# Function to get NSGs to delete based on parameters
function Get-NSGsToDelete {
    param($ResourceGroup, $Name, $BulkDelete, $NamePattern, $ExcludeNames)

    try {
        Write-Host "🔍 Identifying NSGs to delete..." -ForegroundColor Cyan

        $nsgsToDelete = @()
        $excludeList = @()

        if ($ExcludeNames) {
            $excludeList = $ExcludeNames -split ',' | ForEach-Object { $_.Trim() }
        }

        if ($BulkDelete) {
            # Get all NSGs in resource group
            $allNSGs = az network nsg list --resource-group $ResourceGroup --output json | ConvertFrom-Json

            if ($NamePattern) {
                # Filter by pattern
                $filteredNSGs = $allNSGs | Where-Object { $_.name -like $NamePattern }
            }
            else {
                $filteredNSGs = $allNSGs
            }

            # Exclude specified NSGs
            if ($excludeList.Count -gt 0) {
                $filteredNSGs = $filteredNSGs | Where-Object { $_.name -notin $excludeList }
            }

            $nsgsToDelete = $filteredNSGs
        }
        elseif ($Name) {
            # Process specific NSG names
            $nameList = $Name -split ',' | ForEach-Object { $_.Trim() }

            foreach ($nsgName in $nameList) {
                if ($nsgName -notin $excludeList) {
                    try {
                        $nsg = az network nsg show --resource-group $ResourceGroup --name $nsgName --output json 2>$null | ConvertFrom-Json
                        if ($nsg) {
                            $nsgsToDelete += $nsg
                        }
                        else {
                            Write-Warning "NSG '$nsgName' not found in resource group '$ResourceGroup'"
                        }
                    }
                    catch {
                        Write-Warning "Error retrieving NSG '$nsgName': $($_.Exception.Message)"
                    }
                }
                else {
                    Write-Host "   Excluding NSG: $nsgName" -ForegroundColor Yellow
                }
            }
        }
        else {
            throw "Either -Name or -BulkDelete with -NamePattern must be specified"
        }

        if ($nsgsToDelete.Count -eq 0) {
            Write-Warning "No NSGs found matching the specified criteria"
            return @()
        }

        Write-Host "✅ Found $($nsgsToDelete.Count) NSG(s) to delete" -ForegroundColor Green
        return $nsgsToDelete
    }
    catch {
        Write-Error "Error identifying NSGs to delete: $($_.Exception.Message)"
        return @()
    }
}

# Function to check NSG dependencies
function Test-NSGDependencies {
    param($NSG)

    try {
        Write-Host "🔍 Checking dependencies for NSG '$($NSG.name)'..." -ForegroundColor Cyan

        $dependencies = @{
            Subnets = @()
            NetworkInterfaces = @()
            HasDependencies = $false
        }

        # Check subnet associations
        if ($NSG.subnets -and $NSG.subnets.Count -gt 0) {
            $dependencies.Subnets = $NSG.subnets | ForEach-Object {
                $subnetId = $_.id
                $subnetParts = $subnetId -split '/'
                @{
                    Id = $subnetId
                    VNet = $subnetParts[8]
                    Name = $subnetParts[10]
                }
            }
            $dependencies.HasDependencies = $true
        }

        # Check network interface associations
        if ($NSG.networkInterfaces -and $NSG.networkInterfaces.Count -gt 0) {
            $dependencies.NetworkInterfaces = $NSG.networkInterfaces | ForEach-Object {
                @{
                    Id = $_.id
                    Name = ($_.id -split '/')[-1]
                }
            }
            $dependencies.HasDependencies = $true
        }

        if ($dependencies.HasDependencies) {
            Write-Host "⚠️ Dependencies found for NSG '$($NSG.name)':" -ForegroundColor Yellow

            if ($dependencies.Subnets.Count -gt 0) {
                Write-Host "   Subnets:" -ForegroundColor Yellow
                $dependencies.Subnets | ForEach-Object {
                    Write-Host "     - $($_.VNet)/$($_.Name)" -ForegroundColor White
                }
            }

            if ($dependencies.NetworkInterfaces.Count -gt 0) {
                Write-Host "   Network Interfaces:" -ForegroundColor Yellow
                $dependencies.NetworkInterfaces | ForEach-Object {
                    Write-Host "     - $($_.Name)" -ForegroundColor White
                }
            }
        }
        else {
            Write-Host "✅ No dependencies found for NSG '$($NSG.name)'" -ForegroundColor Green
        }

        return $dependencies
    }
    catch {
        Write-Warning "Error checking dependencies for NSG '$($NSG.name)': $($_.Exception.Message)"
        return @{ HasDependencies = $false; Subnets = @(); NetworkInterfaces = @() }
    }
}

# Function to analyze impact of NSG deletion
function Get-NSGImpactAnalysis {
    param($NSG, $Dependencies)

    try {
        Write-Host "🔍 Analyzing impact of deleting NSG '$($NSG.name)'..." -ForegroundColor Cyan

        $impact = @{
            Severity = "Low"
            AffectedResources = 0
            TrafficImpact = @()
            SecurityImpact = @()
            Recommendations = @()
        }

        # Calculate affected resources
        $impact.AffectedResources = $Dependencies.Subnets.Count + $Dependencies.NetworkInterfaces.Count

        if ($Dependencies.HasDependencies) {
            $impact.Severity = "High"

            # Analyze traffic impact
            if ($Dependencies.Subnets.Count -gt 0) {
                $impact.TrafficImpact += "Subnet traffic will fall back to default Azure security rules"
                $impact.TrafficImpact += "Custom security rules will be lost"
            }

            if ($Dependencies.NetworkInterfaces.Count -gt 0) {
                $impact.TrafficImpact += "Network interface traffic will use subnet NSG rules only"
                $impact.TrafficImpact += "NIC-specific security rules will be removed"
            }

            # Analyze security impact
            $restrictiveRules = $NSG.securityRules | Where-Object { $_.access -eq "Deny" }
            $allowRules = $NSG.securityRules | Where-Object { $_.access -eq "Allow" -and $_.priority -lt 4000 }

            if ($restrictiveRules.Count -gt 0) {
                $impact.SecurityImpact += "Loss of $($restrictiveRules.Count) explicit deny rule(s)"
                $impact.Severity = "Critical"
            }

            if ($allowRules.Count -gt 0) {
                $impact.SecurityImpact += "Loss of $($allowRules.Count) custom allow rule(s)"
            }

            # Recommendations
            if ($Dependencies.Subnets.Count -gt 0) {
                $impact.Recommendations += "Consider creating alternative NSG for affected subnets"
                $impact.Recommendations += "Review subnet-level security requirements"
            }

            if ($Dependencies.NetworkInterfaces.Count -gt 0) {
                $impact.Recommendations += "Evaluate need for NIC-level security rules"
                $impact.Recommendations += "Consider moving rules to subnet NSG"
            }

            if ($impact.SecurityImpact.Count -gt 0) {
                $impact.Recommendations += "Document current security rules before deletion"
                $impact.Recommendations += "Plan alternative security measures"
            }
        }

        # Display impact analysis
        Write-Host "📊 Impact Analysis for NSG '$($NSG.name)':" -ForegroundColor Yellow
        Write-Host "   Severity: $($impact.Severity)" -ForegroundColor $(
            switch ($impact.Severity) {
                "Critical" { "Red" }
                "High" { "Yellow" }
                default { "Green" }
            }
        )
        Write-Host "   Affected Resources: $($impact.AffectedResources)" -ForegroundColor White

        if ($impact.TrafficImpact.Count -gt 0) {
            Write-Host "   Traffic Impact:" -ForegroundColor Yellow
            $impact.TrafficImpact | ForEach-Object {
                Write-Host "     - $_" -ForegroundColor White
            }
        }

        if ($impact.SecurityImpact.Count -gt 0) {
            Write-Host "   Security Impact:" -ForegroundColor Red
            $impact.SecurityImpact | ForEach-Object {
                Write-Host "     - $_" -ForegroundColor White
            }
        }

        if ($impact.Recommendations.Count -gt 0) {
            Write-Host "   Recommendations:" -ForegroundColor Cyan
            $impact.Recommendations | ForEach-Object {
                Write-Host "     - $_" -ForegroundColor White
            }
        }

        return $impact
    }
    catch {
        Write-Warning "Error analyzing impact for NSG '$($NSG.name)': $($_.Exception.Message)"
        return @{ Severity = "Unknown"; AffectedResources = 0; TrafficImpact = @(); SecurityImpact = @(); Recommendations = @() }
    }
}

# Function to create NSG backup
function New-NSGBackup {
    param($NSG, $BackupPath)

    try {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

        if (-not $BackupPath) {
            $BackupPath = ".\nsg-backup-$timestamp"
        }

        # Create backup directory
        if (-not (Test-Path $BackupPath)) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
        }

        $backupFile = Join-Path $BackupPath "$($NSG.name)-backup-$timestamp.json"

        Write-Host "💾 Creating backup for NSG '$($NSG.name)'..." -ForegroundColor Cyan

        # Export NSG configuration
        $NSG | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8

        # Create human-readable summary
        $summaryFile = Join-Path $BackupPath "$($NSG.name)-summary-$timestamp.txt"
        $summary = @"
NSG Backup Summary
==================
NSG Name: $($NSG.name)
Resource Group: $($NSG.resourceGroup)
Location: $($NSG.location)
Backup Date: $(Get-Date)

Security Rules ($($NSG.securityRules.Count)):
$($NSG.securityRules | ForEach-Object { "  - $($_.name): $($_.access) $($_.direction) $($_.protocol) $($_.sourcePortRange) -> $($_.destinationPortRange)" } | Out-String)

Subnet Associations ($($NSG.subnets.Count)):
$($NSG.subnets | ForEach-Object { "  - $(($_.id -split '/')[-1])" } | Out-String)

Network Interface Associations ($($NSG.networkInterfaces.Count)):
$($NSG.networkInterfaces | ForEach-Object { "  - $(($_.id -split '/')[-1])" } | Out-String)

Tags:
$($NSG.tags | ConvertTo-Json -Depth 2)
"@

        $summary | Out-File -FilePath $summaryFile -Encoding UTF8

        Write-Host "✅ Backup created: $backupFile" -ForegroundColor Green
        Write-Host "📄 Summary created: $summaryFile" -ForegroundColor Green

        $global:DeletionReport.Summary.BackupsCreated++

        return @{
            BackupFile = $backupFile
            SummaryFile = $summaryFile
            Success = $true
        }
    }
    catch {
        Write-Warning "Error creating backup for NSG '$($NSG.name)': $($_.Exception.Message)"
        return @{
            BackupFile = $null
            SummaryFile = $null
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# Function to delete NSG
function Remove-NSGResource {
    param($NSG, $ResourceGroup, $Timeout, $DryRun)

    try {
        $operationStart = Get-Date

        if ($DryRun) {
            Write-Host "🎭 [DRY RUN] Would delete NSG '$($NSG.name)'" -ForegroundColor Magenta

            $global:DeletionReport.Operations += @{
                NSGName = $NSG.name
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

        Write-Host "🗑️ Deleting NSG '$($NSG.name)'..." -ForegroundColor Yellow

        # Start deletion with timeout
        $job = Start-Job -ScriptBlock {
            param($ResourceGroup, $NSGName)
            az network nsg delete --resource-group $ResourceGroup --name $NSGName --yes --output none 2>&1
            return $LASTEXITCODE
        } -ArgumentList $ResourceGroup, $NSG.name

        # Wait for completion with timeout
        $completed = Wait-Job -Job $job -Timeout $Timeout

        if ($completed) {
            $result = Receive-Job -Job $job
            Remove-Job -Job $job

            if ($result -eq 0) {
                $operationEnd = Get-Date
                $duration = $operationEnd - $operationStart

                Write-Host "✅ NSG '$($NSG.name)' deleted successfully in $($duration.TotalSeconds) seconds" -ForegroundColor Green

                $global:DeletionReport.Operations += @{
                    NSGName = $NSG.name
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
        Write-Error "❌ Failed to delete NSG '$($NSG.name)': $($_.Exception.Message)"

        $global:DeletionReport.Operations += @{
            NSGName = $NSG.name
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
    param($NSGs, $Dependencies, $ImpactAnalysis)

    Write-Host "`n⚠️ DELETION CONFIRMATION" -ForegroundColor Red -BackgroundColor Yellow
    Write-Host "=========================" -ForegroundColor Red -BackgroundColor Yellow

    Write-Host "`nNSGs to be deleted:" -ForegroundColor Yellow
    $NSGs | ForEach-Object {
        Write-Host "  - $($_.name) (Resource Group: $($_.resourceGroup))" -ForegroundColor White
    }

    $totalDependencies = ($Dependencies | ForEach-Object { $_.Subnets.Count + $_.NetworkInterfaces.Count } | Measure-Object -Sum).Sum
    if ($totalDependencies -gt 0) {
        Write-Host "`n⚠️ Total dependent resources: $totalDependencies" -ForegroundColor Red
    }

    $criticalImpacts = $ImpactAnalysis | Where-Object { $_.Severity -eq "Critical" }
    if ($criticalImpacts.Count -gt 0) {
        Write-Host "`n🚨 CRITICAL IMPACT: $($criticalImpacts.Count) NSG(s) have critical security implications" -ForegroundColor Red
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
            $ReportPath = ".\nsg-deletion-report-$timestamp.html"
        }

        $endTime = Get-Date
        $totalDuration = $endTime - $global:DeletionReport.StartTime

        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>NSG Deletion Report</title>
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
    </style>
</head>
<body>
    <div class="header">
        <h1>NSG Deletion Report</h1>
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
    </div>

    <h2>Detailed Operations</h2>
    <table>
        <tr>
            <th>NSG Name</th>
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
            <td>$($operation.NSGName)</td>
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
    Write-Host "🗑️ Starting NSG Deletion Process" -ForegroundColor Red
    Write-Host "=================================" -ForegroundColor Red

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate resource group
    if (-not (Test-ResourceGroupExists -ResourceGroup $ResourceGroup)) {
        exit 1
    }

    # Get NSGs to delete
    $nsgsToDelete = Get-NSGsToDelete -ResourceGroup $ResourceGroup -Name $Name -BulkDelete $BulkDelete -NamePattern $NamePattern -ExcludeNames $ExcludeNames

    if ($nsgsToDelete.Count -eq 0) {
        Write-Warning "No NSGs found to delete"
        exit 0
    }

    $global:DeletionReport.Summary.TotalRequested = $nsgsToDelete.Count

    # Check dependencies and analyze impact
    $allDependencies = @()
    $allImpacts = @()

    foreach ($nsg in $nsgsToDelete) {
        if ($CheckDependencies) {
            $dependencies = Test-NSGDependencies -NSG $nsg
            $allDependencies += $dependencies
        }
        else {
            $allDependencies += @{ HasDependencies = $false; Subnets = @(); NetworkInterfaces = @() }
        }

        if ($AnalyzeImpact) {
            $impact = Get-NSGImpactAnalysis -NSG $nsg -Dependencies $dependencies
            $allImpacts += $impact
        }
        else {
            $allImpacts += @{ Severity = "Unknown" }
        }
    }

    # Show confirmation if not forced and not dry run
    if (-not $Force -and -not $DryRun) {
        $confirmed = Show-DeletionConfirmation -NSGs $nsgsToDelete -Dependencies $allDependencies -ImpactAnalysis $allImpacts
        if (-not $confirmed) {
            Write-Host "❌ Deletion cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }

    # Process each NSG
    for ($i = 0; $i -lt $nsgsToDelete.Count; $i++) {
        $nsg = $nsgsToDelete[$i]
        $dependencies = $allDependencies[$i]

        Write-Host "`n📋 Processing NSG $($i + 1) of $($nsgsToDelete.Count): $($nsg.name)" -ForegroundColor Cyan

        # Skip if has dependencies and not forced
        if ($dependencies.HasDependencies -and -not $Force -and -not $DryRun) {
            Write-Warning "Skipping NSG '$($nsg.name)' due to dependencies. Use -Force to override."
            $global:DeletionReport.Summary.SkippedDeletions++
            continue
        }

        # Create backup if requested
        if ($BackupBeforeDelete -and -not $DryRun) {
            $backup = New-NSGBackup -NSG $nsg -BackupPath $BackupPath
            if (-not $backup.Success) {
                Write-Warning "Backup failed for NSG '$($nsg.name)'. Skipping deletion for safety."
                $global:DeletionReport.Summary.SkippedDeletions++
                continue
            }
        }

        # Delete the NSG
        $deleteResult = Remove-NSGResource -NSG $nsg -ResourceGroup $ResourceGroup -Timeout $Timeout -DryRun $DryRun

        if (-not $deleteResult.Success -and -not $DryRun) {
            Write-Host "❌ Failed to delete NSG '$($nsg.name)'" -ForegroundColor Red
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

    if ($DryRun) {
        Write-Host "`n🎭 This was a dry run. No actual deletions were performed." -ForegroundColor Magenta
    }
}
catch {
    Write-Error "❌ NSG deletion process failed: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 NSG deletion process completed" -ForegroundColor Green
}
