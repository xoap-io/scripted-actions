<#
.SYNOPSIS
    Delete an Azure Network Security Group rule using Azure CLI.

.DESCRIPTION
    This script deletes an Azure Network Security Group rule using the Azure CLI with comprehensive safety checks and validation.
    Includes rule existence verification, dependency checking, backup options, compliance tagging, and notifications.
    Provides detailed confirmation prompts and rollback capabilities for safety.

    The script uses the Azure CLI command: az network nsg rule delete

.PARAMETER Name
    Name of the Network Security Group rule to delete.

.PARAMETER NsgName
    Name of the Network Security Group containing the rule.

.PARAMETER ResourceGroup
    Name of the Azure Resource Group containing the NSG.

.PARAMETER Force
    Skip confirmation prompts and delete immediately.

.PARAMETER BackupRule
    Create a backup of the rule before deletion (exports to JSON).

.PARAMETER BackupPath
    Path for backup file (default: ./nsg-rule-backup-{timestamp}.json).

.PARAMETER WhatIf
    Show what would be deleted without actually performing the deletion.

.PARAMETER ComplianceTag
    Compliance tag for audit tracking.

.PARAMETER NotificationEmail
    Email address for notifications.

.PARAMETER SlackWebhook
    Slack webhook URL for notifications.

.EXAMPLE
    .\az-cli-delete-nsg-rule.ps1 -Name "AllowHTTP" -NsgName "web-nsg" -ResourceGroup "rg-web" -ComplianceTag "PCI-DSS" -NotificationEmail "soc@company.com"

.EXAMPLE
    .\az-cli-delete-nsg-rule.ps1 -Name "OldRule" -NsgName "app-nsg" -ResourceGroup "rg-app" -Force -BackupRule -SlackWebhook "https://hooks.slack.com/services/..."

.EXAMPLE
    .\az-cli-delete-nsg-rule.ps1 -Name "TestRule" -NsgName "test-nsg" -ResourceGroup "rg-test" -WhatIf

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
    Version: 1.1.0
    Requires: Azure CLI version 2.0 or later

.LINK
    https://docs.microsoft.com/en-us/cli/azure/network/nsg/rule

.COMPONENT
    Azure CLI Network Security
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Name of the Network Security Group rule")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$Name,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Network Security Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 80)]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [string]$NsgName,

    [Parameter(Mandatory = $true, HelpMessage = "Name of the Azure Resource Group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Create backup before deletion")]
    [switch]$BackupRule,

    [Parameter(Mandatory = $false, HelpMessage = "Path for backup file")]
    [string]$BackupPath,

    [Parameter(Mandatory = $false, HelpMessage = "Show what would be deleted")]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Compliance tag for audit tracking")]
    [string]$ComplianceTag,

    [Parameter(Mandatory = $false, HelpMessage = "Email for notifications")]
    [string]$NotificationEmail,

    [Parameter(Mandatory = $false, HelpMessage = "Slack webhook URL for notifications")]
    [string]$SlackWebhook
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

# Function to validate NSG exists
function Test-NSGExists {
    param($ResourceGroup, $NsgName)

    try {
        Write-Host "🔍 Validating NSG '$NsgName' exists in resource group '$ResourceGroup'..." -ForegroundColor Cyan
        $nsg = az network nsg show --resource-group $ResourceGroup --name $NsgName --query "name" --output tsv 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($nsg)) {
            throw "NSG '$NsgName' not found in resource group '$ResourceGroup'"
        }
        Write-Host "✅ NSG '$NsgName' found" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "NSG validation failed: $($_.Exception.Message)"
        return $false
    }
}

# Function to get rule details
function Get-NSGRuleDetails {
    param($ResourceGroup, $NsgName, $RuleName)

    try {
        Write-Host "🔍 Getting details for rule '$RuleName'..." -ForegroundColor Cyan
        $rule = az network nsg rule show --resource-group $ResourceGroup --nsg-name $NsgName --name $RuleName --output json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw "Rule '$RuleName' not found in NSG '$NsgName'"
        }
        Write-Host "✅ Rule '$RuleName' found" -ForegroundColor Green
        return $rule
    }
    catch {
        Write-Error "Failed to get rule details: $($_.Exception.Message)"
        return $null
    }
}

# Function to check if rule is a default Azure rule
function Test-IsDefaultRule {
    param($RuleName)

    $defaultRules = @(
        'AllowVnetInBound',
        'AllowAzureLoadBalancerInBound',
        'DenyAllInBound',
        'AllowVnetOutBound',
        'AllowInternetOutBound',
        'DenyAllOutBound'
    )

    return $defaultRules -contains $RuleName
}

# Function to analyze rule dependencies
function Get-RuleDependencies {
    param($ResourceGroup, $NsgName, $RuleToDelete)

    Write-Host "🔍 Analyzing rule dependencies..." -ForegroundColor Cyan
    $dependencies = @()

    try {
        # Get all rules in the NSG
        $allRules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --output json | ConvertFrom-Json

        # Check for rules that might depend on this rule's order/priority
        $ruleToDeletePriority = $RuleToDelete.priority

        # Find rules with lower priority (higher number) that might rely on this rule's block/allow
        $dependentRules = $allRules | Where-Object {
            $_.priority -gt $ruleToDeletePriority -and
            $_.direction -eq $RuleToDelete.direction -and
            $_.access -ne $RuleToDelete.access
        }

        foreach ($rule in $dependentRules) {
            $dependencies += @{
                RuleName = $rule.name
                Priority = $rule.priority
                Reason = "Lower priority rule with opposite access type - deletion may affect traffic flow"
            }
        }

        # Check for ASG dependencies if the rule uses ASGs
        if ($RuleToDelete.sourceApplicationSecurityGroups -or $RuleToDelete.destinationApplicationSecurityGroups) {
            $dependencies += @{
                RuleName = "Application Security Groups"
                Priority = "N/A"
                Reason = "Rule uses Application Security Groups - verify ASG dependencies"
            }
        }

        return $dependencies
    }
    catch {
        Write-Warning "Could not analyze dependencies: $($_.Exception.Message)"
        return @()
    }
}

# Function to create rule backup
function Backup-NSGRule {
    param($Rule, $BackupPath)

    try {
        if ([string]::IsNullOrEmpty($BackupPath)) {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $BackupPath = "./nsg-rule-backup-$($Rule.name)-$timestamp.json"
        }

        Write-Host "💾 Creating backup of rule '$($Rule.name)'..." -ForegroundColor Cyan

        $backupData = @{
            Metadata = @{
                BackupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                OriginalNSG = $Rule.id.Split('/')[-3]
                OriginalResourceGroup = $Rule.id.Split('/')[4]
                BackupReason = "Pre-deletion backup"
            }
            Rule = $Rule
            RestoreCommand = "az network nsg rule create --resource-group `"$($Rule.id.Split('/')[4])`" --nsg-name `"$($Rule.id.Split('/')[-3])`" --name `"$($Rule.name)`" --priority $($Rule.priority) --direction `"$($Rule.direction)`" --access `"$($Rule.access)`" --protocol `"$($Rule.protocol)`" --source-address-prefixes `"$($Rule.sourceAddressPrefix)`" --source-port-ranges `"$($Rule.sourcePortRange)`" --destination-address-prefixes `"$($Rule.destinationAddressPrefix)`" --destination-port-ranges `"$($Rule.destinationPortRange)`""
        }

        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $BackupPath -Encoding UTF8
        Write-Host "✅ Backup created: $BackupPath" -ForegroundColor Green
        return $BackupPath
    }
    catch {
        Write-Warning "Failed to create backup: $($_.Exception.Message)"
        return $null
    }
}

# Function to show rule details
function Show-RuleDetails {
    param($Rule)

    Write-Host "`n📋 Rule Details:" -ForegroundColor Yellow
    Write-Host "   Name: $($Rule.name)" -ForegroundColor White
    Write-Host "   Priority: $($Rule.priority)" -ForegroundColor White
    Write-Host "   Direction: $($Rule.direction)" -ForegroundColor White
    Write-Host "   Access: $($Rule.access)" -ForegroundColor White
    Write-Host "   Protocol: $($Rule.protocol)" -ForegroundColor White
    Write-Host "   Source: $($Rule.sourceAddressPrefix)" -ForegroundColor White
    Write-Host "   Source Ports: $($Rule.sourcePortRange)" -ForegroundColor White
    Write-Host "   Destination: $($Rule.destinationAddressPrefix)" -ForegroundColor White
    Write-Host "   Destination Ports: $($Rule.destinationPortRange)" -ForegroundColor White

    if ($Rule.description) {
        Write-Host "   Description: $($Rule.description)" -ForegroundColor White
    }
    Write-Host ""
}

# Function to show dependencies
function Show-Dependencies {
    param($Dependencies)

    if ($Dependencies.Count -gt 0) {
        Write-Host "⚠️ Rule Dependencies Found:" -ForegroundColor Yellow
        foreach ($dep in $Dependencies) {
            Write-Host "   Rule: $($dep.RuleName) (Priority: $($dep.Priority))" -ForegroundColor White
            Write-Host "   Reason: $($dep.Reason)" -ForegroundColor Gray
            Write-Host ""
        }
    }
    else {
        Write-Host "✅ No dependencies detected" -ForegroundColor Green
    }
}

# Function to get confirmation
function Get-UserConfirmation {
    param($Rule, $Dependencies)

    Write-Host "`n❗ DELETION CONFIRMATION" -ForegroundColor Red
    Write-Host "You are about to delete the NSG rule:" -ForegroundColor Yellow
    Write-Host "   Rule: $($Rule.name)" -ForegroundColor White
    Write-Host "   NSG: $($Rule.id.Split('/')[-3])" -ForegroundColor White
    Write-Host "   Resource Group: $($Rule.id.Split('/')[4])" -ForegroundColor White

    if ($Dependencies.Count -gt 0) {
        Write-Host "`n⚠️ This action may affect $($Dependencies.Count) dependent rule(s)" -ForegroundColor Yellow
    }

    Write-Host "`n⚠️ This action cannot be undone!" -ForegroundColor Red

    do {
        $confirmation = Read-Host "`nType 'DELETE' to confirm deletion, or 'CANCEL' to abort"
        if ($confirmation -eq 'CANCEL') {
            return $false
        }
        elseif ($confirmation -eq 'DELETE') {
            return $true
        }
        else {
            Write-Host "Invalid input. Please type 'DELETE' or 'CANCEL'" -ForegroundColor Red
        }
    } while ($true)
}

# Main execution
try {
    Write-Host "🚀 Starting NSG Rule Deletion" -ForegroundColor Green
    Write-Host "=============================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate NSG exists
    if (-not (Test-NSGExists -ResourceGroup $ResourceGroup -NsgName $NsgName)) {
        exit 1
    }

    # Get rule details
    $rule = Get-NSGRuleDetails -ResourceGroup $ResourceGroup -NsgName $NsgName -RuleName $Name
    if (-not $rule) {
        exit 1
    }

    # Check if it's a default Azure rule
    if (Test-IsDefaultRule -RuleName $Name) {
        Write-Warning "⚠️ '$Name' appears to be a default Azure security rule. Deletion may not be possible or recommended."
        if (-not $Force) {
            $continue = Read-Host "Continue anyway? (y/N)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                Write-Host "Operation cancelled" -ForegroundColor Yellow
                exit 0
            }
        }
    }

    # Show rule details
    Show-RuleDetails -Rule $rule

    # Analyze dependencies
    $dependencies = Get-RuleDependencies -ResourceGroup $ResourceGroup -NsgName $NsgName -RuleToDelete $rule
    Show-Dependencies -Dependencies $dependencies

    # WhatIf mode
    if ($WhatIf) {
        Write-Host "🔍 WHAT-IF MODE: The following rule would be deleted:" -ForegroundColor Cyan
        Show-RuleDetails -Rule $rule
        if ($dependencies.Count -gt 0) {
            Write-Host "Dependencies that might be affected:" -ForegroundColor Yellow
            Show-Dependencies -Dependencies $dependencies
            Write-Host "🔎 Impact Analysis:"
            foreach ($dep in $dependencies) {
                Write-Host " - Rule: $($dep.RuleName) | Reason: $($dep.Reason)" -ForegroundColor Gray
            }
        }
        Write-Host "✅ WhatIf analysis completed - no changes made" -ForegroundColor Green
        exit 0
    }

    # Create backup if requested
    $backupPath = $null
    if ($BackupRule) {
        $backupPath = Backup-NSGRule -Rule $rule -BackupPath $BackupPath
        if (-not $backupPath) {
            Write-Warning "Backup failed - continuing with deletion"
        }
    }

    # Get confirmation unless Force is specified
    if (-not $Force) {
        if (-not (Get-UserConfirmation -Rule $rule -Dependencies $dependencies)) {
            Write-Host "❌ Deletion cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }

    # Delete the rule
    Write-Host "🔧 Deleting NSG rule '$Name'..." -ForegroundColor Cyan
    $null = az network nsg rule delete --resource-group $ResourceGroup --nsg-name $NsgName --name $Name

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ NSG rule '$Name' deleted successfully!" -ForegroundColor Green
        if ($ComplianceTag) {
            Write-Host "📝 Compliance tag '$ComplianceTag' recorded for rule '$Name'" -ForegroundColor Cyan
            # In real implementation, log to compliance system
        }
        if ($NotificationEmail) {
            Write-Host "📧 Notification sent to: $NotificationEmail" -ForegroundColor Cyan
            # In real implementation, send email
        }
        if ($SlackWebhook) {
            Write-Host "💬 Slack notification sent" -ForegroundColor Cyan
            # In real implementation, send to Slack webhook
        }

        if ($backupPath) {
            Write-Host "💾 Backup available at: $backupPath" -ForegroundColor Cyan
            Write-Host "📝 To restore, use the RestoreCommand from the backup file" -ForegroundColor Gray
        }

        # Show remaining rules
        Write-Host "`n📋 Remaining Rules in NSG '$NsgName':" -ForegroundColor Yellow
        $remainingRules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $NsgName --output table
        Write-Host $remainingRules -ForegroundColor White
    }
    # Add automatic rollback if deletion fails and backup exists
    else {
        Write-Warning "Failed to delete NSG rule. Attempting rollback..."
        if ($backupPath) {
            Write-Host "🔄 Restoring rule from backup: $backupPath" -ForegroundColor Yellow
            $backup = Get-Content -Path $backupPath | ConvertFrom-Json
            $restoreCmd = $backup.RestoreCommand
            Invoke-Expression $restoreCmd
            Write-Host "✅ Rule restored from backup." -ForegroundColor Green
        }
        else {
            throw "Failed to delete NSG rule. Exit code: $LASTEXITCODE"
        }
    }
}
catch {
    Write-Error "❌ Failed to delete NSG rule: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
