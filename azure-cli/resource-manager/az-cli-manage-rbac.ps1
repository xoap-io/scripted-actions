<#
.SYNOPSIS
    Manage Azure Role-Based Access Control (RBAC) using Azure CLI.

.DESCRIPTION
    This script manages Azure RBAC assignments using the Azure CLI for Resource Groups, subscriptions, and resources.
    Supports creating, listing, and deleting role assignments with comprehensive reporting and bulk operations.
    Includes security auditing, custom role management, and access review capabilities.

    The script uses the Azure CLI commands: az role assignment create, az role assignment list, az role assignment delete

.PARAMETER Operation
    RBAC operation to perform.

.PARAMETER PrincipalId
    Object ID of the user, group, or service principal.

.PARAMETER PrincipalType
    Type of principal (User, Group, ServicePrincipal).

.PARAMETER RoleName
    Name of the Azure built-in role or custom role.

.PARAMETER Scope
    Scope for the role assignment (subscription, resource group, or resource).

.PARAMETER ResourceGroup
    Resource Group name for RG-scoped assignments.

.PARAMETER Resource
    Specific resource ID for resource-scoped assignments.

.PARAMETER AssignmentDescription
    Description for the role assignment.

.PARAMETER ShowInherited
    Include inherited role assignments in listings.

.PARAMETER ExportReport
    Export RBAC report to JSON file.

.PARAMETER ValidateAssignment
    Validate role assignment before creating.

.PARAMETER BulkOperation
    Perform bulk operations using CSV input file.

.PARAMETER InputFile
    CSV file for bulk operations with columns: PrincipalId, RoleName, Scope.

.PARAMETER Force
    Force operations without confirmation prompts.

.EXAMPLE
    .\az-cli-manage-rbac.ps1 -Operation "assign" -PrincipalId "12345678-1234-1234-1234-123456789abc" -RoleName "Reader" -ResourceGroup "production-rg"

    Assigns Reader role to user on Resource Group.

.EXAMPLE
    .\az-cli-manage-rbac.ps1 -Operation "list" -ResourceGroup "dev-rg" -ShowInherited -ExportReport "rbac-report.json"

    Lists all role assignments on Resource Group with inherited assignments.

.EXAMPLE
    .\az-cli-manage-rbac.ps1 -Operation "remove" -PrincipalId "87654321-4321-4321-4321-210987654321" -RoleName "Contributor" -Scope "subscription"

    Removes Contributor role from user at subscription level.

.EXAMPLE
    .\az-cli-manage-rbac.ps1 -Operation "bulk-assign" -InputFile "rbac-assignments.csv" -ValidateAssignment

    Performs bulk role assignments from CSV file with validation.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

.LINK
    https://learn.microsoft.com/en-us/cli/azure/role/assignment

.COMPONENT
    Azure CLI Resource Manager
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "RBAC operation to perform")]
    [ValidateSet("assign", "list", "remove", "audit", "bulk-assign", "show")]
    [string]$Operation,

    [Parameter(HelpMessage = "Object ID of the user, group, or service principal")]
    [ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')]
    [string]$PrincipalId,

    [Parameter(HelpMessage = "Type of principal")]
    [ValidateSet("User", "Group", "ServicePrincipal")]
    [string]$PrincipalType = "User",

    [Parameter(HelpMessage = "Name of the Azure role")]
    [ValidateSet(
        "Owner", "Contributor", "Reader", "User Access Administrator",
        "Virtual Machine Contributor", "Storage Account Contributor", "Network Contributor",
        "SQL DB Contributor", "Website Contributor", "Classic Storage Account Contributor",
        "Storage Blob Data Contributor", "Storage Blob Data Reader", "Key Vault Contributor",
        "Backup Contributor", "Backup Reader", "Monitoring Contributor", "Monitoring Reader"
    )]
    [string]$RoleName,

    [Parameter(HelpMessage = "Scope for the role assignment")]
    [ValidateSet("subscription", "resourceGroup", "resource")]
    [string]$Scope = "resourceGroup",

    [Parameter(HelpMessage = "Resource Group name for RG-scoped assignments")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._\-\(\)]+$')]
    [string]$ResourceGroup,

    [Parameter(HelpMessage = "Specific resource ID for resource-scoped assignments")]
    [string]$Resource,

    [Parameter(HelpMessage = "Description for the role assignment")]
    [ValidateLength(0, 512)]
    [string]$AssignmentDescription,

    [Parameter(HelpMessage = "Include inherited role assignments in listings")]
    [switch]$ShowInherited,

    [Parameter(HelpMessage = "Export RBAC report to JSON file")]
    [string]$ExportReport,

    [Parameter(HelpMessage = "Validate role assignment before creating")]
    [switch]$ValidateAssignment,

    [Parameter(HelpMessage = "Perform bulk operations using CSV input")]
    [switch]$BulkOperation,

    [Parameter(HelpMessage = "CSV file for bulk operations")]
    [ValidateScript({Test-Path $_ -PathType 'Leaf'})]
    [string]$InputFile,

    [Parameter(HelpMessage = "Force operations without confirmation")]
    [switch]$Force,

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

    Write-Host "🔐 Azure RBAC Management" -ForegroundColor Blue
    Write-Host "========================" -ForegroundColor Blue
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
    if ($Operation -in @("assign", "remove") -and -not $PrincipalId) {
        throw "PrincipalId parameter is required for assign/remove operations"
    }

    if ($Operation -in @("assign", "remove") -and -not $RoleName) {
        throw "RoleName parameter is required for assign/remove operations"
    }

    if ($Scope -eq "resourceGroup" -and -not $ResourceGroup) {
        throw "ResourceGroup parameter is required for Resource Group scope"
    }

    if ($Scope -eq "resource" -and -not $Resource) {
        throw "Resource parameter is required for resource scope"
    }

    if ($BulkOperation -and -not $InputFile) {
        throw "InputFile parameter is required for bulk operations"
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

    # Build scope string
    $scopeString = switch ($Scope) {
        "subscription" { "/subscriptions/$($azAccount.id)" }
        "resourceGroup" { "/subscriptions/$($azAccount.id)/resourceGroups/$ResourceGroup" }
        "resource" { $Resource }
    }

    # Display operation configuration
    Write-Host "RBAC Operation Configuration:" -ForegroundColor Cyan
    Write-Host "  Operation: $Operation" -ForegroundColor White
    Write-Host "  Scope: $Scope" -ForegroundColor White

    if ($PrincipalId) {
        Write-Host "  Principal ID: $PrincipalId" -ForegroundColor White
        Write-Host "  Principal Type: $PrincipalType" -ForegroundColor White
    }

    if ($RoleName) {
        Write-Host "  Role: $RoleName" -ForegroundColor White
    }

    if ($ResourceGroup) {
        Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
    }

    if ($Resource) {
        Write-Host "  Resource: $($Resource -split '/')[-1]" -ForegroundColor White
    }

    Write-Host ""

    # Execute operations
    switch ($Operation) {
        "assign" {
            Write-Host "👤 Creating role assignment..." -ForegroundColor Blue

            # Validate principal exists
            if ($ValidateAssignment) {
                Write-Host "Validating principal..." -ForegroundColor Yellow
                try {
                    $principalInfo = az ad user show --id $PrincipalId 2>$null
                    if (-not $principalInfo) {
                        $principalInfo = az ad group show --group $PrincipalId 2>$null
                    }
                    if (-not $principalInfo) {
                        $principalInfo = az ad sp show --id $PrincipalId 2>$null
                    }

                    if ($principalInfo) {
                        $principal = $principalInfo | ConvertFrom-Json
                        Write-Host "✓ Principal found: $($principal.displayName)" -ForegroundColor Green
                    } else {
                        throw "Principal with ID '$PrincipalId' not found"
                    }
                }
                catch {
                    Write-Host "⚠ Warning: Could not validate principal: $($_.Exception.Message)" -ForegroundColor Yellow
                }
            }

            # Check if assignment already exists
            Write-Host "Checking for existing assignment..." -ForegroundColor Yellow
            $existingAssignment = az role assignment list --assignee $PrincipalId --role $RoleName --scope $scopeString | ConvertFrom-Json

            if ($existingAssignment -and $existingAssignment.Count -gt 0) {
                if (-not $Force) {
                    Write-Host "⚠ Role assignment already exists!" -ForegroundColor Yellow
                    Write-Host "Principal '$PrincipalId' already has role '$RoleName' at scope '$scopeString'" -ForegroundColor White

                    $confirmation = Read-Host "Do you want to continue anyway? (yes/no)"
                    if ($confirmation -ne "yes") {
                        Write-Host "Role assignment cancelled." -ForegroundColor Yellow
                        return
                    }
                } else {
                    Write-Host "⚠ Role assignment already exists but Force parameter specified" -ForegroundColor Yellow
                }
            }

            # Build role assignment command
            $azParams = @('role', 'assignment', 'create', '--assignee', $PrincipalId, '--role', $RoleName, '--scope', $scopeString)

            if ($AssignmentDescription) {
                $azParams += '--description', $AssignmentDescription
            }

            # Execute role assignment
            $result = & az @azParams 2>&1

            if ($LASTEXITCODE -eq 0) {
                $assignmentInfo = $result | ConvertFrom-Json
                Write-Host "✓ Role assignment created successfully!" -ForegroundColor Green
                Write-Host ""
                Write-Host "Assignment Details:" -ForegroundColor Cyan
                Write-Host "  Principal ID: $($assignmentInfo.principalId)" -ForegroundColor White
                Write-Host "  Role: $($assignmentInfo.roleDefinitionName)" -ForegroundColor White
                Write-Host "  Scope: $($assignmentInfo.scope)" -ForegroundColor White
                if ($assignmentInfo.description) {
                    Write-Host "  Description: $($assignmentInfo.description)" -ForegroundColor White
                }
                Write-Host "  Assignment ID: $($assignmentInfo.id)" -ForegroundColor Gray
            } else {
                throw "Failed to create role assignment: $($result -join "`n")"
            }
        }

        "list" {
            Write-Host "📋 Listing role assignments..." -ForegroundColor Blue

            # Build list command
            $azParams = @('role', 'assignment', 'list', '--scope', $scopeString, '--output', 'json')

            if (-not $ShowInherited) {
                $azParams += '--include-inherited', 'false'
            }

            # Execute role assignment listing
            $result = & az @azParams 2>&1

            if ($LASTEXITCODE -eq 0) {
                $assignments = $result | ConvertFrom-Json

                if (-not $assignments) {
                    $assignments = @()
                }

                Write-Host "✓ Found $($assignments.Count) role assignment(s)" -ForegroundColor Green
                Write-Host ""

                if ($assignments.Count -eq 0) {
                    Write-Host "No role assignments found in the specified scope." -ForegroundColor Yellow
                } else {
                    Write-Host "Role Assignments:" -ForegroundColor Blue
                    Write-Host $("-" * 100) -ForegroundColor Gray

                    # Group assignments by role
                    $roleGroups = $assignments | Group-Object -Property roleDefinitionName

                    foreach ($roleGroup in $roleGroups) {
                        Write-Host ""
                        Write-Host "🔑 $($roleGroup.Name) ($($roleGroup.Count) assignment(s))" -ForegroundColor Blue

                        foreach ($assignment in $roleGroup.Group) {
                            Write-Host "  • Principal: $($assignment.principalId)" -ForegroundColor White
                            Write-Host "    Type: $($assignment.principalType)" -ForegroundColor Gray
                            Write-Host "    Scope: $($assignment.scope)" -ForegroundColor Gray
                            if ($assignment.description) {
                                Write-Host "    Description: $($assignment.description)" -ForegroundColor Gray
                            }
                            Write-Host "    Created: $($assignment.createdOn)" -ForegroundColor Gray
                            Write-Host ""
                        }
                    }

                    # Summary statistics
                    Write-Host "Assignment Summary:" -ForegroundColor Cyan
                    $principalTypes = $assignments | Group-Object -Property principalType
                    foreach ($typeGroup in $principalTypes) {
                        Write-Host "  $($typeGroup.Name): $($typeGroup.Count)" -ForegroundColor White
                    }
                }

                # Export report if requested
                if ($ExportReport) {
                    $reportData = @{
                        timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
                        subscription = $azAccount.id
                        scope = $scopeString
                        assignmentCount = $assignments.Count
                        assignments = $assignments
                        summary = @{
                            roleBreakdown = ($assignments | Group-Object -Property roleDefinitionName | ForEach-Object { @{ role = $_.Name; count = $_.Count } })
                            principalTypeBreakdown = ($assignments | Group-Object -Property principalType | ForEach-Object { @{ type = $_.Name; count = $_.Count } })
                        }
                    }

                    $reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $ExportReport -Encoding UTF8
                    Write-Host ""
                    Write-Host "✓ RBAC report exported to: $ExportReport" -ForegroundColor Green
                }
            } else {
                throw "Failed to list role assignments: $($result -join "`n")"
            }
        }

        "remove" {
            Write-Host "🗑️ Removing role assignment..." -ForegroundColor Red

            # Check if assignment exists
            Write-Host "Verifying assignment exists..." -ForegroundColor Yellow
            $existingAssignment = az role assignment list --assignee $PrincipalId --role $RoleName --scope $scopeString | ConvertFrom-Json

            if (-not $existingAssignment -or $existingAssignment.Count -eq 0) {
                Write-Host "⚠ No matching role assignment found!" -ForegroundColor Yellow
                Write-Host "Principal '$PrincipalId' does not have role '$RoleName' at scope '$scopeString'" -ForegroundColor White
                return
            }

            if (-not $Force) {
                Write-Host ""
                Write-Host "⚠ Role Assignment Removal Confirmation" -ForegroundColor Yellow
                Write-Host "This will remove the following role assignment:" -ForegroundColor White
                Write-Host "  Principal: $PrincipalId" -ForegroundColor Red
                Write-Host "  Role: $RoleName" -ForegroundColor Red
                Write-Host "  Scope: $scopeString" -ForegroundColor Red
                Write-Host ""

                $confirmation = Read-Host "Do you want to proceed with removal? (yes/no)"
                if ($confirmation -ne "yes") {
                    Write-Host "Role assignment removal cancelled." -ForegroundColor Yellow
                    return
                }
            }

            # Build remove command
            $azParams = @('role', 'assignment', 'delete', '--assignee', $PrincipalId, '--role', $RoleName, '--scope', $scopeString)

            # Execute role assignment removal
            $result = & az @azParams 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Host "✓ Role assignment removed successfully!" -ForegroundColor Green
            } else {
                throw "Failed to remove role assignment: $($result -join "`n")"
            }
        }

        "audit" {
            Write-Host "🔍 Performing RBAC audit..." -ForegroundColor Blue

            # Get all role assignments in scope
            $allAssignments = az role assignment list --scope $scopeString --include-inherited | ConvertFrom-Json

            Write-Host "✓ Retrieved $($allAssignments.Count) role assignments for audit" -ForegroundColor Green
            Write-Host ""

            # Audit analysis
            Write-Host "🔍 RBAC Audit Report:" -ForegroundColor Cyan
            Write-Host $("-" * 60) -ForegroundColor Gray

            # Check for overprivileged assignments
            $ownerAssignments = $allAssignments | Where-Object { $_.roleDefinitionName -eq "Owner" }
            $contributorAssignments = $allAssignments | Where-Object { $_.roleDefinitionName -eq "Contributor" }

            Write-Host ""
            Write-Host "🚨 High-Privilege Assignments:" -ForegroundColor Red
            Write-Host "  Owner assignments: $($ownerAssignments.Count)" -ForegroundColor Red
            Write-Host "  Contributor assignments: $($contributorAssignments.Count)" -ForegroundColor Yellow

            if ($ownerAssignments.Count -gt 0) {
                Write-Host ""
                Write-Host "Owner Role Assignments:" -ForegroundColor Red
                foreach ($owner in $ownerAssignments) {
                    Write-Host "  • $($owner.principalId) ($($owner.principalType))" -ForegroundColor Red
                }
            }

            # Check for service principal assignments
            $spAssignments = $allAssignments | Where-Object { $_.principalType -eq "ServicePrincipal" }
            Write-Host ""
            Write-Host "🤖 Service Principal Assignments: $($spAssignments.Count)" -ForegroundColor Blue

            # Check for custom roles
            $customRoleAssignments = $allAssignments | Where-Object { $_.roleDefinitionId -notlike "*/providers/Microsoft.Authorization/roleDefinitions/*" }
            Write-Host "🎯 Custom Role Assignments: $($customRoleAssignments.Count)" -ForegroundColor Magenta

            # Recent assignments (if available)
            $recentAssignments = $allAssignments | Where-Object {
                $_.createdOn -and ([DateTime]$_.createdOn) -gt (Get-Date).AddDays(-30)
            }
            Write-Host "🕒 Recent Assignments (30 days): $($recentAssignments.Count)" -ForegroundColor Green

            Write-Host ""
            Write-Host "📊 Role Distribution:" -ForegroundColor Cyan
            $roleDistribution = $allAssignments | Group-Object -Property roleDefinitionName | Sort-Object Count -Descending
            foreach ($role in $roleDistribution) {
                Write-Host "  $($role.Name): $($role.Count)" -ForegroundColor White
            }
        }

        "bulk-assign" {
            if (-not $InputFile) {
                throw "InputFile parameter is required for bulk operations"
            }

            Write-Host "📁 Performing bulk role assignments..." -ForegroundColor Blue
            Write-Host "Input file: $InputFile" -ForegroundColor Yellow

            # Load CSV file
            $assignments = Import-Csv -Path $InputFile
            Write-Host "✓ Loaded $($assignments.Count) assignments from CSV" -ForegroundColor Green

            $successCount = 0
            $errorCount = 0

            foreach ($assignment in $assignments) {
                try {
                    Write-Host "Processing: $($assignment.PrincipalId) -> $($assignment.RoleName)" -ForegroundColor Yellow

                    $bulkParams = @('role', 'assignment', 'create', '--assignee', $assignment.PrincipalId, '--role', $assignment.RoleName, '--scope', $assignment.Scope)

                    & az @bulkParams | Out-Null
                    Write-Host "  ✓ Success" -ForegroundColor Green
                    $successCount++
                }
                catch {
                    Write-Host "  ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
                    $errorCount++
                }
            }

            Write-Host ""
            Write-Host "Bulk Assignment Summary:" -ForegroundColor Cyan
            Write-Host "  Successful: $successCount" -ForegroundColor Green
            Write-Host "  Failed: $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
        }
    }

    Write-Host ""
    Write-Host "🏁 RBAC operation completed successfully" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
