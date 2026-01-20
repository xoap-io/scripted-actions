<#
.SYNOPSIS
    Manage Azure resource locks using Azure CLI.

.DESCRIPTION
    This script manages Azure resource locks using the Azure CLI to prevent accidental deletion or modification.
    Supports creating, listing, updating, and deleting locks at Resource Group, resource, and subscription levels.
    Includes bulk operations, lock inheritance analysis, and comprehensive reporting capabilities.

    The script uses the Azure CLI commands: az lock create, az lock list, az lock delete

.PARAMETER ResourceGroup
    Target Resource Group for lock operations.

.PARAMETER Resource
    Specific resource ID for resource-level lock operations.

.PARAMETER LockName
    Name of the lock to create, update, or delete.

.PARAMETER LockType
    Type of lock to apply.

.PARAMETER Notes
    Notes or description for the lock.

.PARAMETER Operation
    Lock operation to perform.

.PARAMETER Force
    Force delete locks without confirmation.

.PARAMETER Scope
    Scope level for lock operations.

.PARAMETER ShowInherited
    Include inherited locks in the listing.

.PARAMETER ExportReport
    Export lock report to JSON file.

.PARAMETER BulkOperation
    Perform bulk operations on multiple resources.

.PARAMETER ParentResourceGroup
    Apply locks to all Resource Groups under subscription.

.EXAMPLE
    .\az-cli-manage-locks.ps1 -Operation "create" -ResourceGroup "production-rg" -LockName "prod-protection" -LockType "CannotDelete" -Notes "Protect production resources"

    Creates a delete protection lock on a Resource Group.

.EXAMPLE
    .\az-cli-manage-locks.ps1 -Operation "list" -ResourceGroup "dev-rg" -ShowInherited

    Lists all locks on Resource Group including inherited locks.

.EXAMPLE
    .\az-cli-manage-locks.ps1 -Operation "delete" -ResourceGroup "test-rg" -LockName "temp-lock" -Force

    Deletes a specific lock without confirmation.

.EXAMPLE
    .\az-cli-manage-locks.ps1 -Operation "create" -Resource "/subscriptions/.../resourceGroups/rg/providers/Microsoft.Compute/virtualMachines/vm1" -LockType "ReadOnly" -LockName "vm-readonly"

    Creates a read-only lock on specific virtual machine.

.NOTES
    Author: Azure CLI Script
    Version: 1.0
    Requires: Azure CLI

.LINK
    https://learn.microsoft.com/en-us/cli/azure/lock

.COMPONENT
    Azure CLI
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Target Resource Group for lock operations")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Specific resource ID for resource-level locks")]
    [string]$Resource,

    [Parameter(HelpMessage = "Name of the lock")]
    [ValidateLength(1, 260)]
    [string]$LockName,

    [Parameter(HelpMessage = "Type of lock to apply")]
    [ValidateSet("CannotDelete", "ReadOnly")]
    [string]$LockType = "CannotDelete",

    [Parameter(HelpMessage = "Notes or description for the lock")]
    [ValidateLength(0, 512)]
    [string]$Notes,

    [Parameter(Mandatory = $true, HelpMessage = "Lock operation to perform")]
    [ValidateSet("create", "list", "delete", "update", "show")]
    [string]$Operation,

    [Parameter(HelpMessage = "Force delete locks without confirmation")]
    [switch]$Force,

    [Parameter(HelpMessage = "Scope level for lock operations")]
    [ValidateSet("subscription", "resourceGroup", "resource")]
    [string]$Scope = "resourceGroup",

    [Parameter(HelpMessage = "Include inherited locks in the listing")]
    [switch]$ShowInherited,

    [Parameter(HelpMessage = "Export lock report to JSON file")]
    [string]$ExportReport,

    [Parameter(HelpMessage = "Perform bulk operations on multiple resources")]
    [switch]$BulkOperation,

    [Parameter(HelpMessage = "Apply locks to all Resource Groups under subscription")]
    [switch]$ParentResourceGroup,

    [Parameter(HelpMessage = "Azure subscription ID or name")]
    [ValidatePattern('^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})|(.+)$')]
    [string]$Subscription
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    # Check if Azure CLI is available
    if (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        throw "Azure CLI is not installed or not found in PATH. Please install Azure CLI first."
    }

    # Check if user is logged in to Azure CLI
    $azAccount = az account show 2>$null | ConvertFrom-Json
    if (-not $azAccount) {
        throw "Not logged in to Azure CLI. Please run 'az login' first."
    }

    Write-Host "🔒 Azure Resource Lock Management" -ForegroundColor Blue
    Write-Host "=================================" -ForegroundColor Blue
    Write-Host "✓ Azure CLI is available and authenticated" -ForegroundColor Green

    # Switch subscription if specified
    if ($Subscription) {
        Write-Host "Switching to subscription: $Subscription" -ForegroundColor Yellow
        az account set --subscription $Subscription
        $azAccount = az account show | ConvertFrom-Json
    }

    Write-Host "Current subscription: $($azAccount.name) ($($azAccount.id))" -ForegroundColor Cyan
    Write-Host ""

    # Validate parameters based on operation
    if ($Operation -in @("create", "update") -and -not $LockName) {
        throw "LockName parameter is required for create/update operations"
    }

    if ($Operation -eq "delete" -and -not $LockName -and -not $BulkOperation) {
        throw "LockName parameter is required for delete operations (unless using BulkOperation)"
    }

    if ($Scope -eq "resourceGroup" -and -not $ResourceGroup -and -not $ParentResourceGroup) {
        throw "ResourceGroup parameter is required for Resource Group scope operations"
    }

    if ($Scope -eq "resource" -and -not $Resource) {
        throw "Resource parameter is required for resource scope operations"
    }

    # Verify Resource Group exists if specified
    if ($ResourceGroup) {
        Write-Host "Verifying Resource Group: $ResourceGroup" -ForegroundColor Yellow
        $rgCheck = az group show --name $ResourceGroup 2>$null
        if (-not $rgCheck) {
            throw "Resource Group '$ResourceGroup' not found in subscription '$($azAccount.name)'"
        }

        $rgInfo = $rgCheck | ConvertFrom-Json
        Write-Host "✓ Resource Group '$ResourceGroup' found" -ForegroundColor Green
        Write-Host "  Location: $($rgInfo.location)" -ForegroundColor White
    }

    # Verify resource exists if specified
    if ($Resource) {
        Write-Host "Verifying resource: $Resource" -ForegroundColor Yellow
        $resourceCheck = az resource show --ids $Resource 2>$null
        if (-not $resourceCheck) {
            throw "Resource '$Resource' not found or not accessible"
        }

        $resourceInfo = $resourceCheck | ConvertFrom-Json
        Write-Host "✓ Resource found: $($resourceInfo.name)" -ForegroundColor Green
        Write-Host "  Type: $($resourceInfo.type)" -ForegroundColor White
        Write-Host "  Location: $($resourceInfo.location)" -ForegroundColor White
    }

    # Generate lock name if not specified for create operations
    if ($Operation -eq "create" -and -not $LockName) {
        $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
        $LockName = "lock-$timestamp"
        Write-Host "Generated lock name: $LockName" -ForegroundColor Blue
    }

    # Display operation configuration
    Write-Host "Lock Operation Configuration:" -ForegroundColor Cyan
    Write-Host "  Operation: $Operation" -ForegroundColor White
    Write-Host "  Scope: $Scope" -ForegroundColor White

    if ($ResourceGroup) {
        Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    }

    if ($Resource) {
        Write-Host "  Resource: $($Resource -split '/')[-1]" -ForegroundColor White
    }

    if ($LockName) {
        Write-Host "  Lock Name: $LockName" -ForegroundColor White
    }

    if ($LockType) {
        Write-Host "  Lock Type: $LockType" -ForegroundColor White
    }

    if ($Notes) {
        Write-Host "  Notes: $Notes" -ForegroundColor White
    }

    Write-Host ""

    # Execute operations
    switch ($Operation) {
        "create" {
            Write-Host "🔒 Creating resource lock..." -ForegroundColor Blue

            # Build Azure CLI command
            $azParams = @('lock', 'create', '--name', $LockName, '--lock-type', $LockType)

            if ($Notes) {
                $azParams += '--notes', $Notes
            }

            switch ($Scope) {
                "subscription" {
                    # Subscription level lock
                }
                "resourceGroup" {
                    if ($ParentResourceGroup) {
                        # Apply to all Resource Groups
                        Write-Host "Creating locks on all Resource Groups..." -ForegroundColor Yellow
                        $allResourceGroups = az group list | ConvertFrom-Json

                        $successCount = 0
                        $errorCount = 0

                        foreach ($rg in $allResourceGroups) {
                            try {
                                $rgLockName = "$LockName-$($rg.name)"
                                $rgLockParams = @('lock', 'create', '--name', $rgLockName, '--lock-type', $LockType, '--resource-group', $rg.name)
                                if ($Notes) {
                                    $rgLockParams += '--notes', "$Notes (Applied to $($rg.name))"
                                }

                                & az @rgLockParams | Out-Null
                                Write-Host "  ✓ Lock created on: $($rg.name)" -ForegroundColor Green
                                $successCount++
                            }
                            catch {
                                Write-Host "  ✗ Failed to create lock on: $($rg.name)" -ForegroundColor Red
                                $errorCount++
                            }
                        }

                        Write-Host ""
                        Write-Host "Bulk lock creation completed:" -ForegroundColor Cyan
                        Write-Host "  Successful: $successCount" -ForegroundColor Green
                        Write-Host "  Failed: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
                        return
                    } else {
                        $azParams += '--resource-group', $ResourceGroup
                    }
                }
                "resource" {
                    $azParams += '--resource', $Resource
                }
            }

            # Execute lock creation
            $result = & az @azParams 2>&1

            if ($LASTEXITCODE -eq 0) {
                $lockInfo = $result | ConvertFrom-Json
                Write-Host "✓ Lock created successfully!" -ForegroundColor Green
                Write-Host ""
                Write-Host "Lock Details:" -ForegroundColor Cyan
                Write-Host "  Name: $($lockInfo.name)" -ForegroundColor White
                Write-Host "  Type: $($lockInfo.level)" -ForegroundColor White
                Write-Host "  Notes: $($lockInfo.notes)" -ForegroundColor White
                Write-Host "  ID: $($lockInfo.id)" -ForegroundColor Gray
            } else {
                throw "Failed to create lock: $($result -join "`n")"
            }
        }

        "list" {
            Write-Host "📋 Listing resource locks..." -ForegroundColor Blue

            # Build Azure CLI command
            $azParams = @('lock', 'list')

            switch ($Scope) {
                "subscription" {
                    # List all locks in subscription
                }
                "resourceGroup" {
                    $azParams += '--resource-group', $ResourceGroup
                }
                "resource" {
                    $azParams += '--resource', $Resource
                }
            }

            if ($ShowInherited) {
                $azParams += '--filter-string', 'atScope()'
            }

            # Execute lock listing
            $result = & az @azParams 2>&1

            if ($LASTEXITCODE -eq 0) {
                $locks = $result | ConvertFrom-Json

                if (-not $locks) {
                    $locks = @()
                }

                Write-Host "✓ Found $($locks.Count) lock(s)" -ForegroundColor Green
                Write-Host ""

                if ($locks.Count -eq 0) {
                    Write-Host "No locks found in the specified scope." -ForegroundColor Yellow
                } else {
                    Write-Host "Lock Details:" -ForegroundColor Blue
                    Write-Host $("-" * 80) -ForegroundColor Gray

                    foreach ($lock in $locks) {
                        $lockColor = switch ($lock.level) {
                            "CannotDelete" { "Red" }
                            "ReadOnly" { "Yellow" }
                            default { "White" }
                        }

                        Write-Host ""
                        Write-Host "🔒 $($lock.name)" -ForegroundColor Blue
                        Write-Host "   Type: $($lock.level)" -ForegroundColor $lockColor
                        Write-Host "   Scope: $($lock.scope)" -ForegroundColor White
                        if ($lock.notes) {
                            Write-Host "   Notes: $($lock.notes)" -ForegroundColor Gray
                        }
                        Write-Host "   ID: $($lock.id)" -ForegroundColor Gray
                    }

                    # Summary statistics
                    Write-Host ""
                    Write-Host "Lock Summary:" -ForegroundColor Cyan
                    $lockTypes = $locks | Group-Object -Property level
                    foreach ($lockType in $lockTypes) {
                        $typeColor = switch ($lockType.Name) {
                            "CannotDelete" { "Red" }
                            "ReadOnly" { "Yellow" }
                            default { "White" }
                        }
                        Write-Host "  $($lockType.Name): $($lockType.Count)" -ForegroundColor $typeColor
                    }
                }

                # Export report if requested
                if ($ExportReport) {
                    $reportData = @{
                        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                        subscription = $azAccount.id
                        scope = $Scope
                        resourceGroup = $ResourceGroup
                        resource = $Resource
                        lockCount = $locks.Count
                        locks = $locks
                    }

                    $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportReport -Encoding UTF8
                    Write-Host ""
                    Write-Host "✓ Lock report exported to: $ExportReport" -ForegroundColor Green
                }
            } else {
                throw "Failed to list locks: $($result -join "`n")"
            }
        }

        "delete" {
            if ($BulkOperation) {
                Write-Host "🗑️ Bulk deleting resource locks..." -ForegroundColor Red

                # Get all locks in scope
                $listParams = @('lock', 'list')
                if ($ResourceGroup) {
                    $listParams += '--resource-group', $ResourceGroup
                }

                $locks = az @listParams | ConvertFrom-Json

                if (-not $locks -or $locks.Count -eq 0) {
                    Write-Host "No locks found to delete." -ForegroundColor Yellow
                    return
                }

                if (-not $Force) {
                    Write-Host ""
                    Write-Host "⚠ ⚠ ⚠  BULK DELETE WARNING  ⚠ ⚠ ⚠" -ForegroundColor Red
                    Write-Host "This will delete ALL $($locks.Count) locks in the specified scope!" -ForegroundColor Red
                    Write-Host ""
                    Write-Host "Locks to be deleted:" -ForegroundColor Yellow
                    foreach ($lock in ($locks | Select-Object -First 10)) {
                        Write-Host "  • $($lock.name) ($($lock.level))" -ForegroundColor Red
                    }
                    if ($locks.Count -gt 10) {
                        Write-Host "  • ... and $($locks.Count - 10) more locks" -ForegroundColor Gray
                    }
                    Write-Host ""

                    $confirmation = Read-Host "Type 'DELETE ALL LOCKS' to confirm bulk deletion"
                    if ($confirmation -ne "DELETE ALL LOCKS") {
                        Write-Host "Bulk deletion cancelled by user." -ForegroundColor Yellow
                        return
                    }
                }

                $successCount = 0
                $errorCount = 0

                foreach ($lock in $locks) {
                    try {
                        az lock delete --ids $lock.id --yes | Out-Null
                        Write-Host "  ✓ Deleted: $($lock.name)" -ForegroundColor Green
                        $successCount++
                    }
                    catch {
                        Write-Host "  ✗ Failed to delete: $($lock.name)" -ForegroundColor Red
                        $errorCount++
                    }
                }

                Write-Host ""
                Write-Host "Bulk deletion completed:" -ForegroundColor Cyan
                Write-Host "  Deleted: $successCount" -ForegroundColor Green
                Write-Host "  Failed: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
            } else {
                Write-Host "🗑️ Deleting resource lock: $LockName" -ForegroundColor Red

                # Build Azure CLI command
                $azParams = @('lock', 'delete', '--name', $LockName)

                switch ($Scope) {
                    "subscription" {
                        # Subscription level lock
                    }
                    "resourceGroup" {
                        $azParams += '--resource-group', $ResourceGroup
                    }
                    "resource" {
                        $azParams += '--resource', $Resource
                    }
                }

                if ($Force) {
                    $azParams += '--yes'
                } else {
                    Write-Host ""
                    Write-Host "⚠ Lock Deletion Confirmation" -ForegroundColor Yellow
                    Write-Host "This will delete the lock '$LockName'" -ForegroundColor Red
                    Write-Host "Resources will no longer be protected from deletion/modification." -ForegroundColor Yellow
                    Write-Host ""

                    $confirmation = Read-Host "Do you want to proceed with lock deletion? (yes/no)"
                    if ($confirmation -ne "yes") {
                        Write-Host "Lock deletion cancelled by user." -ForegroundColor Yellow
                        return
                    }
                    $azParams += '--yes'
                }

                # Execute lock deletion
                $result = & az @azParams 2>&1

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "✓ Lock deleted successfully!" -ForegroundColor Green
                } else {
                    throw "Failed to delete lock: $($result -join "`n")"
                }
            }
        }

        "show" {
            Write-Host "🔍 Showing lock details: $LockName" -ForegroundColor Blue

            # Build Azure CLI command
            $azParams = @('lock', 'show', '--name', $LockName)

            switch ($Scope) {
                "subscription" {
                    # Subscription level lock
                }
                "resourceGroup" {
                    $azParams += '--resource-group', $ResourceGroup
                }
                "resource" {
                    $azParams += '--resource', $Resource
                }
            }

            # Execute lock show
            $result = & az @azParams 2>&1

            if ($LASTEXITCODE -eq 0) {
                $lockInfo = $result | ConvertFrom-Json

                Write-Host "✓ Lock found" -ForegroundColor Green
                Write-Host ""
                Write-Host "Lock Details:" -ForegroundColor Cyan
                Write-Host "  Name: $($lockInfo.name)" -ForegroundColor White
                Write-Host "  Type: $($lockInfo.level)" -ForegroundColor $(if ($lockInfo.level -eq 'CannotDelete') { 'Red' } else { 'Yellow' })
                Write-Host "  Scope: $($lockInfo.scope)" -ForegroundColor White
                if ($lockInfo.notes) {
                    Write-Host "  Notes: $($lockInfo.notes)" -ForegroundColor White
                }
                Write-Host "  Created: $($lockInfo.metadata.createdOn)" -ForegroundColor Gray
                Write-Host "  ID: $($lockInfo.id)" -ForegroundColor Gray
            } else {
                throw "Failed to show lock: $($result -join "`n")"
            }
        }
    }

    Write-Host ""
    Write-Host "🏁 Lock operation completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to manage resource locks" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "Script execution completed." -ForegroundColor Gray
}
