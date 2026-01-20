<#
.SYNOPSIS
    Assign Azure RBAC roles using Azure CLI with comprehensive validation.

.DESCRIPTION
    This script assigns Azure RBAC roles using the Azure CLI with advanced validation and security best practices.
    Supports role assignment to users, groups, service principals, and managed identities.
    Includes scope validation, role definition verification, and assignment conflict checking.

    The script uses the Azure CLI command: az role assignment create

.PARAMETER Role
    Name or ID of the Azure RBAC role to assign.

.PARAMETER Assignee
    Email, object ID, or principal name of the assignee.

.PARAMETER AssigneeObjectId
    Object ID of the assignee (use instead of Assignee for service principals).

.PARAMETER Scope
    Scope for the role assignment (subscription, resource group, or resource).

.PARAMETER ResourceGroup
    Resource group name (when scope is resource group level).

.PARAMETER Resource
    Resource name (when scope is resource level).

.PARAMETER ResourceType
    Resource type (when scope is resource level).

.PARAMETER Condition
    Conditional assignment expression (for Azure ABAC).

.PARAMETER ConditionVersion
    Version of the condition format.

.PARAMETER Description
    Description for the role assignment.

.PARAMETER WhatIf
    Show what would be assigned without performing the assignment.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER ValidateOnly
    Only validate the assignment without creating it.

.EXAMPLE
    .\az-cli-assign-role.ps1 -Role "Reader" -Assignee "user@company.com" -Scope "/subscriptions/12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\az-cli-assign-role.ps1 -Role "Contributor" -Assignee "devteam@company.com" -ResourceGroup "rg-production" -Description "Production access for dev team"

.EXAMPLE
    .\az-cli-assign-role.ps1 -Role "Storage Blob Data Reader" -AssigneeObjectId "abcd1234-5678-90ab-cdef-123456789012" -ResourceGroup "rg-storage" -Resource "storageaccount" -ResourceType "Microsoft.Storage/storageAccounts"

.EXAMPLE
    .\az-cli-assign-role.ps1 -Role "Virtual Machine Contributor" -Assignee "webapp-identity" -ResourceGroup "rg-compute" -WhatIf

.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later

    RBAC Best Practices:
    - Use least privilege principle
    - Assign roles at appropriate scope
    - Use groups instead of individual users
    - Regularly review and audit assignments
    - Use conditional access when needed
    - Document role assignments

.LINK
    https://docs.microsoft.com/en-us/cli/azure/role/assignment

.COMPONENT
    Azure CLI RBAC Security
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure RBAC role name or ID")]
    [ValidateNotNullOrEmpty()]
    [string]$Role,

    [Parameter(Mandatory = $false, HelpMessage = "Assignee email, object ID, or principal name")]
    [string]$Assignee,

    [Parameter(Mandatory = $false, HelpMessage = "Assignee object ID")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$AssigneeObjectId,

    [Parameter(Mandatory = $false, HelpMessage = "Assignment scope")]
    [string]$Scope,

    [Parameter(Mandatory = $false, HelpMessage = "Resource group name")]
    [ValidateLength(1, 90)]
    [ValidatePattern('^[a-zA-Z0-9._()-]+$')]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Resource name")]
    [string]$Resource,

    [Parameter(Mandatory = $false, HelpMessage = "Resource type")]
    [string]$ResourceType,

    [Parameter(Mandatory = $false, HelpMessage = "Conditional assignment expression")]
    [string]$Condition,

    [Parameter(Mandatory = $false, HelpMessage = "Condition version")]
    [ValidateSet('2.0')]
    [string]$ConditionVersion = '2.0',

    [Parameter(Mandatory = $false, HelpMessage = "Assignment description")]
    [ValidateLength(0, 512)]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Show what would be assigned")]
    [switch]$WhatIf,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompts")]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = "Only validate without creating")]
    [switch]$ValidateOnly
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

# Function to validate role definition exists
function Test-RoleDefinition {
    param($RoleName)

    try {
        Write-Host "🔍 Validating role definition '$RoleName'..." -ForegroundColor Cyan

        # Try to get role by name first
        $role = az role definition list --name $RoleName --output json | ConvertFrom-Json

        if (-not $role -or $role.Count -eq 0) {
            # Try by role ID if it looks like a GUID
            if ($RoleName -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') {
                $role = az role definition show --name $RoleName --output json | ConvertFrom-Json
            }
        }

        if (-not $role) {
            throw "Role definition '$RoleName' not found"
        }

        Write-Host "✅ Role definition found: $($role.roleName)" -ForegroundColor Green
        return $role
    }
    catch {
        Write-Error "Role validation failed: $($_.Exception.Message)"
        return $null
    }
}

# Function to resolve assignee information
function Get-AssigneeInfo {
    param($Assignee, $ObjectId)

    try {
        if ($ObjectId) {
            Write-Host "🔍 Getting assignee info by object ID '$ObjectId'..." -ForegroundColor Cyan

            # Try to get user first
            $user = az ad user show --id $ObjectId --output json 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $user) {
                return @{
                    ObjectId = $user.id
                    DisplayName = $user.displayName
                    Type = "User"
                    Principal = $user.userPrincipalName
                }
            }

            # Try to get group
            $group = az ad group show --group $ObjectId --output json 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $group) {
                return @{
                    ObjectId = $group.id
                    DisplayName = $group.displayName
                    Type = "Group"
                    Principal = $group.displayName
                }
            }

            # Try to get service principal
            $sp = az ad sp show --id $ObjectId --output json 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $sp) {
                return @{
                    ObjectId = $sp.id
                    DisplayName = $sp.displayName
                    Type = "ServicePrincipal"
                    Principal = $sp.appDisplayName
                }
            }

            throw "Assignee with object ID '$ObjectId' not found"
        }
        elseif ($Assignee) {
            Write-Host "🔍 Resolving assignee '$Assignee'..." -ForegroundColor Cyan

            # Try email/UPN for user
            if ($Assignee -match '@') {
                $user = az ad user show --id $Assignee --output json 2>$null | ConvertFrom-Json
                if ($LASTEXITCODE -eq 0 -and $user) {
                    return @{
                        ObjectId = $user.id
                        DisplayName = $user.displayName
                        Type = "User"
                        Principal = $user.userPrincipalName
                    }
                }
            }

            # Try as group name
            $group = az ad group show --group $Assignee --output json 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $group) {
                return @{
                    ObjectId = $group.id
                    DisplayName = $group.displayName
                    Type = "Group"
                    Principal = $group.displayName
                }
            }

            # Try as service principal display name
            $sp = az ad sp list --display-name $Assignee --output json 2>$null | ConvertFrom-Json
            if ($LASTEXITCODE -eq 0 -and $sp -and $sp.Count -gt 0) {
                return @{
                    ObjectId = $sp[0].id
                    DisplayName = $sp[0].displayName
                    Type = "ServicePrincipal"
                    Principal = $sp[0].appDisplayName
                }
            }

            throw "Assignee '$Assignee' not found"
        }
        else {
            throw "Either Assignee or AssigneeObjectId must be provided"
        }
    }
    catch {
        Write-Error "Assignee resolution failed: $($_.Exception.Message)"
        return $null
    }
}

# Function to build and validate scope
function Get-ValidatedScope {
    param($Scope, $ResourceGroup, $Resource, $ResourceType)

    try {
        if ($Scope) {
            Write-Host "🔍 Validating provided scope '$Scope'..." -ForegroundColor Cyan

            # Validate scope format
            if ($Scope -notmatch '^/subscriptions/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}') {
                throw "Invalid scope format. Must start with /subscriptions/{subscription-id}"
            }

            Write-Host "✅ Scope format is valid" -ForegroundColor Green
            return $Scope
        }

        # Build scope from components
        $subscription = az account show --query "id" --output tsv
        $builtScope = "/subscriptions/$subscription"

        if ($ResourceGroup) {
            Write-Host "🔍 Validating resource group '$ResourceGroup'..." -ForegroundColor Cyan
            $null = az group show --name $ResourceGroup --query "name" --output tsv 2>$null
            if ($LASTEXITCODE -ne 0) {
                throw "Resource group '$ResourceGroup' not found"
            }

            $builtScope += "/resourceGroups/$ResourceGroup"

            if ($Resource -and $ResourceType) {
                Write-Host "🔍 Validating resource '$Resource' of type '$ResourceType'..." -ForegroundColor Cyan

                # Check if resource exists
                $null = az resource show --resource-group $ResourceGroup --name $Resource --resource-type $ResourceType --query "name" --output tsv 2>$null
                if ($LASTEXITCODE -ne 0) {
                    throw "Resource '$Resource' of type '$ResourceType' not found in resource group '$ResourceGroup'"
                }

                $builtScope += "/providers/$ResourceType/$Resource"
            }
        }

        Write-Host "✅ Built scope: $builtScope" -ForegroundColor Green
        return $builtScope
    }
    catch {
        Write-Error "Scope validation failed: $($_.Exception.Message)"
        return $null
    }
}

# Function to check for existing role assignments
function Test-ExistingAssignment {
    param($AssigneeObjectId, $Role, $Scope)

    try {
        Write-Host "🔍 Checking for existing role assignments..." -ForegroundColor Cyan

        $existingAssignments = az role assignment list --assignee $AssigneeObjectId --scope $Scope --output json | ConvertFrom-Json

        $conflictingAssignment = $existingAssignments | Where-Object {
            $_.roleDefinitionName -eq $Role -or $_.roleDefinitionId -eq $Role
        }

        if ($conflictingAssignment) {
            Write-Host "⚠️ Existing assignment found:" -ForegroundColor Yellow
            Write-Host "   Role: $($conflictingAssignment.roleDefinitionName)" -ForegroundColor White
            Write-Host "   Scope: $($conflictingAssignment.scope)" -ForegroundColor White
            Write-Host "   Created: $($conflictingAssignment.createdOn)" -ForegroundColor White
            return $conflictingAssignment
        }

        Write-Host "✅ No conflicting assignments found" -ForegroundColor Green
        return $null
    }
    catch {
        Write-Warning "Could not check existing assignments: $($_.Exception.Message)"
        return $null
    }
}

# Function to display assignment summary
function Show-AssignmentSummary {
    param($Role, $Assignee, $Scope, $Description, $Condition)

    Write-Host "`n📋 Role Assignment Summary:" -ForegroundColor Yellow
    Write-Host "   Role: $($Role.roleName)" -ForegroundColor White
    Write-Host "   Role Type: $($Role.roleType)" -ForegroundColor White
    Write-Host "   Assignee: $($Assignee.DisplayName) ($($Assignee.Type))" -ForegroundColor White
    Write-Host "   Principal: $($Assignee.Principal)" -ForegroundColor White
    Write-Host "   Scope: $Scope" -ForegroundColor White

    if ($Description) {
        Write-Host "   Description: $Description" -ForegroundColor White
    }

    if ($Condition) {
        Write-Host "   Condition: $Condition" -ForegroundColor White
    }

    Write-Host "`n📄 Role Permissions:" -ForegroundColor Yellow
    if ($Role.permissions -and $Role.permissions.Count -gt 0) {
        foreach ($permission in $Role.permissions) {
            if ($permission.actions -and $permission.actions.Count -gt 0) {
                Write-Host "   Actions: $($permission.actions -join ', ')" -ForegroundColor White
            }
            if ($permission.notActions -and $permission.notActions.Count -gt 0) {
                Write-Host "   Not Actions: $($permission.notActions -join ', ')" -ForegroundColor Yellow
            }
            if ($permission.dataActions -and $permission.dataActions.Count -gt 0) {
                Write-Host "   Data Actions: $($permission.dataActions -join ', ')" -ForegroundColor White
            }
        }
    }
    Write-Host ""
}

# Function to get user confirmation
function Get-UserConfirmation {
    param($Role, $Assignee, $Scope)

    Write-Host "❗ ROLE ASSIGNMENT CONFIRMATION" -ForegroundColor Red
    Write-Host "You are about to assign the following role:" -ForegroundColor Yellow
    Write-Host "   Role: $($Role.roleName)" -ForegroundColor White
    Write-Host "   To: $($Assignee.DisplayName) ($($Assignee.Type))" -ForegroundColor White
    Write-Host "   Scope: $Scope" -ForegroundColor White

    Write-Host "`n⚠️ This will grant the specified permissions!" -ForegroundColor Yellow

    do {
        $confirmation = Read-Host "`nType 'ASSIGN' to confirm, or 'CANCEL' to abort"
        if ($confirmation -eq 'CANCEL') {
            return $false
        }
        elseif ($confirmation -eq 'ASSIGN') {
            return $true
        }
        else {
            Write-Host "Invalid input. Please type 'ASSIGN' or 'CANCEL'" -ForegroundColor Red
        }
    } while ($true)
}

# Main execution
try {
    Write-Host "🚀 Starting Azure RBAC Role Assignment" -ForegroundColor Green
    Write-Host "======================================" -ForegroundColor Green

    # Validate Azure CLI
    if (-not (Test-AzureCLI)) {
        exit 1
    }

    # Validate role definition
    $roleDefinition = Test-RoleDefinition -RoleName $Role
    if (-not $roleDefinition) {
        exit 1
    }

    # Resolve assignee information
    $assigneeInfo = Get-AssigneeInfo -Assignee $Assignee -ObjectId $AssigneeObjectId
    if (-not $assigneeInfo) {
        exit 1
    }

    # Build and validate scope
    $validatedScope = Get-ValidatedScope -Scope $Scope -ResourceGroup $ResourceGroup -Resource $Resource -ResourceType $ResourceType
    if (-not $validatedScope) {
        exit 1
    }

    # Check for existing assignments
    $existingAssignment = Test-ExistingAssignment -AssigneeObjectId $assigneeInfo.ObjectId -Role $Role -Scope $validatedScope
    if ($existingAssignment) {
        if (-not $Force) {
            $continue = Read-Host "Assignment already exists. Continue anyway? (y/N)"
            if ($continue -ne 'y' -and $continue -ne 'Y') {
                Write-Host "Operation cancelled" -ForegroundColor Yellow
                exit 0
            }
        }
    }

    # Display assignment summary
    Show-AssignmentSummary -Role $roleDefinition -Assignee $assigneeInfo -Scope $validatedScope -Description $Description -Condition $Condition

    # WhatIf mode
    if ($WhatIf) {
        Write-Host "🔍 WHAT-IF MODE: The following role would be assigned:" -ForegroundColor Cyan
        Write-Host "✅ WhatIf analysis completed - no changes made" -ForegroundColor Green
        exit 0
    }

    # Validation only mode
    if ($ValidateOnly) {
        Write-Host "✅ Validation completed - assignment is valid and ready to create" -ForegroundColor Green
        exit 0
    }

    # Get confirmation unless Force is specified
    if (-not $Force) {
        if (-not (Get-UserConfirmation -Role $roleDefinition -Assignee $assigneeInfo -Scope $validatedScope)) {
            Write-Host "❌ Assignment cancelled by user" -ForegroundColor Yellow
            exit 0
        }
    }

    # Build assignment parameters
    $azParams = @(
        'role', 'assignment', 'create',
        '--role', $Role,
        '--assignee-object-id', $assigneeInfo.ObjectId,
        '--assignee-principal-type', $assigneeInfo.Type,
        '--scope', $validatedScope
    )

    # Add optional parameters
    if ($Description) { $azParams += '--description', $Description }
    if ($Condition) {
        $azParams += '--condition', $Condition
        $azParams += '--condition-version', $ConditionVersion
    }

    # Create the role assignment
    Write-Host "🔧 Creating role assignment..." -ForegroundColor Cyan
    $assignment = az @azParams --output json | ConvertFrom-Json

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Role assignment created successfully!" -ForegroundColor Green

        # Display assignment details
        Write-Host "`n📝 Assignment Details:" -ForegroundColor Yellow
        Write-Host "   Assignment ID: $($assignment.id)" -ForegroundColor White
        Write-Host "   Role: $($assignment.roleDefinitionName)" -ForegroundColor White
        Write-Host "   Principal: $($assignment.principalName)" -ForegroundColor White
        Write-Host "   Scope: $($assignment.scope)" -ForegroundColor White
        Write-Host "   Created: $($assignment.createdOn)" -ForegroundColor White

        if ($assignment.description) {
            Write-Host "   Description: $($assignment.description)" -ForegroundColor White
        }

        # Show verification command
        Write-Host "`n💡 To verify the assignment:" -ForegroundColor Cyan
        Write-Host "   az role assignment list --assignee `"$($assigneeInfo.ObjectId)`" --scope `"$validatedScope`"" -ForegroundColor Gray
    }
    else {
        throw "Failed to create role assignment. Exit code: $LASTEXITCODE"
    }
}
catch {
    Write-Error "❌ Failed to assign role: $($_.Exception.Message)"
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
