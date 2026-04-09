<#
.SYNOPSIS
    Assign an Intune configuration policy (Settings Catalog) to an Entra ID group via the Microsoft Graph API.

.DESCRIPTION
    This script assigns a Microsoft Intune Settings Catalog configuration policy to an Entra ID
    group, all devices, or all users using the Microsoft Graph API. The policy is resolved by
    display name or Policy ID, and the target group is resolved by display name or Object ID.
    Current assignments are displayed before and after the operation.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoints:
      GET /deviceManagement/configurationPolicies
      GET /groups
      GET /deviceManagement/configurationPolicies/{id}/assignments
      POST /deviceManagement/configurationPolicies/{id}/assign

.PARAMETER PolicyNameOrId
    The display name or Policy ID (GUID) of the Settings Catalog configuration policy.

.PARAMETER GroupNameOrId
    The display name or Object ID (GUID) of the Entra ID group to assign the policy to.
    Not required when -AllDevices or -AllUsers is specified.

.PARAMETER Intent
    The assignment intent. Valid values: apply, remove. Defaults to apply.

.PARAMETER AllDevices
    Assign the policy to all managed devices instead of a specific group.

.PARAMETER AllUsers
    Assign the policy to all licensed users instead of a specific group.

.EXAMPLE
    .\msgraph-assign-intune-config-policy.ps1 -PolicyNameOrId "Windows Security Baseline" -GroupNameOrId "SG-IT-Devices"
    Assigns the configuration policy to the specified Entra ID group.

.EXAMPLE
    .\msgraph-assign-intune-config-policy.ps1 -PolicyNameOrId "00000000-0000-0000-0000-000000000000" -AllDevices
    Assigns the policy identified by GUID to all managed devices.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft Graph connection (pre-established by XOAP)
    Permissions: DeviceManagementConfiguration.ReadWrite.All (Application), Group.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-deviceconfiguration-assign

.COMPONENT
    Microsoft Graph Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The display name or Policy ID of the Settings Catalog configuration policy")]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyNameOrId,

    [Parameter(Mandatory = $false, HelpMessage = "The display name or Object ID of the Entra ID group to assign the policy to")]
    [string]$GroupNameOrId,

    [Parameter(Mandatory = $false, HelpMessage = "Assignment intent: apply or remove")]
    [ValidateSet('apply', 'remove')]
    [string]$Intent = 'apply',

    [Parameter(Mandatory = $false, HelpMessage = "Assign the policy to all managed devices")]
    [switch]$AllDevices,

    [Parameter(Mandatory = $false, HelpMessage = "Assign the policy to all licensed users")]
    [switch]$AllUsers
)

$ErrorActionPreference = 'Stop'

# Validate assignment target
if (-not $GroupNameOrId -and -not $AllDevices -and -not $AllUsers) {
    Write-Host "❌ You must specify -GroupNameOrId, -AllDevices, or -AllUsers as the assignment target." -ForegroundColor Red
    exit 1
}

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "⚙️  Intune Configuration Policy Assignment" -ForegroundColor Blue
    Write-Host "==========================================" -ForegroundColor Blue

    # Resolve policy
    Write-Host "🔍 Resolving configuration policy: $PolicyNameOrId..." -ForegroundColor Cyan
    $isGuid = $PolicyNameOrId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

    if ($isGuid) {
        $policy = Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/configurationPolicies/$PolicyNameOrId`?`$select=id,name,description,platforms,technologies" -Method GET
    }
    else {
        $policiesResponse = Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/configurationPolicies?`$filter=name eq '$([Uri]::EscapeDataString($PolicyNameOrId))'&`$select=id,name,description,platforms,technologies" -Method GET
        $policy = $policiesResponse.value | Select-Object -First 1
        if (-not $policy) {
            Write-Host "❌ No configuration policy found with name: $PolicyNameOrId" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host "✅ Found policy: $($policy.name) (Id: $($policy.id))" -ForegroundColor Green

    # Show current assignments
    Write-Host "`n🔍 Retrieving current assignments..." -ForegroundColor Cyan
    $currentAssignments = Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/configurationPolicies/$($policy.id)/assignments" -Method GET
    if ($currentAssignments.value.Count -gt 0) {
        Write-Host "   Current assignments ($($currentAssignments.value.Count)):" -ForegroundColor White
        $currentAssignments.value | ForEach-Object {
            Write-Host "     - Target: $($_.target.'@odata.type')" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "   No current assignments." -ForegroundColor Gray
    }

    # Build assignment target
    $assignmentTarget = @{}

    if ($AllDevices) {
        Write-Host "`nℹ️  Target: All Devices" -ForegroundColor Yellow
        $assignmentTarget = @{ '@odata.type' = '#microsoft.graph.allDevicesAssignmentTarget' }
    }
    elseif ($AllUsers) {
        Write-Host "`nℹ️  Target: All Users" -ForegroundColor Yellow
        $assignmentTarget = @{ '@odata.type' = '#microsoft.graph.allLicensedUsersAssignmentTarget' }
    }
    else {
        # Resolve group
        Write-Host "`n🔍 Resolving group: $GroupNameOrId..." -ForegroundColor Cyan
        $isGroupGuid = $GroupNameOrId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

        if ($isGroupGuid) {
            $group = Invoke-MgGraphRequest -Uri "$GraphBase/groups/$GroupNameOrId`?`$select=id,displayName" -Method GET
        }
        else {
            $groupsResponse = Invoke-MgGraphRequest -Uri "$GraphBase/groups?`$filter=displayName eq '$([Uri]::EscapeDataString($GroupNameOrId))'&`$select=id,displayName" -Method GET
            $group = $groupsResponse.value | Select-Object -First 1
            if (-not $group) {
                Write-Host "❌ No group found with name: $GroupNameOrId" -ForegroundColor Red
                exit 1
            }
        }
        Write-Host "✅ Found group: $($group.displayName) (Id: $($group.id))" -ForegroundColor Green
        $assignmentTarget = @{
            '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
            groupId       = $group.id
        }
    }

    # Build assignment body
    $assignBody = @{
        assignments = @(
            @{
                target = $assignmentTarget
            }
        )
    } | ConvertTo-Json -Depth 8

    # Perform assignment
    Write-Host "`n🔧 Applying assignment (intent: $Intent)..." -ForegroundColor Cyan
    Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/configurationPolicies/$($policy.id)/assign" -Method POST -Body $assignBody -ContentType "application/json"

    Write-Host "✅ Policy '$($policy.name)' assigned successfully" -ForegroundColor Green

    # Show updated assignments
    Write-Host "`n🔍 Updated assignments:" -ForegroundColor Cyan
    $updatedAssignments = Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/configurationPolicies/$($policy.id)/assignments" -Method GET
    $updatedAssignments.value | ForEach-Object {
        Write-Host "   - Target: $($_.target.'@odata.type')" -ForegroundColor White
        if ($_.target.groupId) { Write-Host "     Group Id: $($_.target.groupId)" -ForegroundColor Gray }
    }

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Policy deployment may take up to 8 hours for all targeted devices to receive it" -ForegroundColor White
    Write-Host "   - Monitor deployment status in the Intune portal under Device Configuration" -ForegroundColor White
}
catch {
    Write-Host "❌ Failed to assign configuration policy: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
