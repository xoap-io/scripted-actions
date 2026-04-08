<#
.SYNOPSIS
    Assign a Microsoft Intune app to an Entra ID group via the Microsoft Graph API.

.DESCRIPTION
    This script assigns a mobile app configured in Microsoft Intune to an Entra ID group
    using the Microsoft Graph API. Supports required, available, and uninstall assignment
    intents, and can target both included and excluded groups.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint:
    POST /deviceAppManagement/mobileApps/{id}/assign

.PARAMETER AppId
    Object ID of the Intune app to assign.

.PARAMETER GroupId
    Object ID of the Entra ID group to assign the app to.

.PARAMETER Intent
    Assignment intent. Valid values: required, available, uninstall, availableWithoutEnrollment.

.PARAMETER ExcludeGroup
    When specified, the group is added as an exclusion rather than an inclusion.

.PARAMETER InstallTimeSettings
    When intent is 'required', optionally specify a deadline as a datetime string.
    Example: "2025-12-31T23:59:59Z"

.EXAMPLE
    .\msgraph-assign-intune-app.ps1 -AppId "00000000-0000-0000-0000-000000000000" -GroupId "11111111-1111-1111-1111-111111111111" -Intent required
    Assigns the app as required for the specified group.

.EXAMPLE
    .\msgraph-assign-intune-app.ps1 -AppId "00000000-0000-0000-0000-000000000000" -GroupId "11111111-1111-1111-1111-111111111111" -Intent available
    Makes the app available (optional) for the specified group.

.EXAMPLE
    .\msgraph-assign-intune-app.ps1 -AppId "00000000-0000-0000-0000-000000000000" -GroupId "22222222-2222-2222-2222-222222222222" -Intent required -ExcludeGroup
    Excludes the group from a required app assignment.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: DeviceManagementApps.ReadWrite.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileapp-assign

.COMPONENT
    Microsoft Graph, Microsoft Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Object ID of the Intune app")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$AppId,

    [Parameter(Mandatory = $true, HelpMessage = "Object ID of the target Entra ID group")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$GroupId,

    [Parameter(Mandatory = $true, HelpMessage = "Assignment intent")]
    [ValidateSet('required', 'available', 'uninstall', 'availableWithoutEnrollment')]
    [string]$Intent,

    [Parameter(Mandatory = $false, HelpMessage = "Add the group as an exclusion instead of inclusion")]
    [switch]$ExcludeGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Deadline for required installs (ISO 8601 datetime)")]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')]
    [string]$InstallTimeSettings
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    Write-Host "📦 Intune App Assignment" -ForegroundColor Blue
    Write-Host "========================" -ForegroundColor Blue

    # Look up app details
    Write-Host "🔍 Looking up app: $AppId..." -ForegroundColor Cyan
    $app = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$AppId`?`$select=id,displayName,@odata.type" -Method GET
    Write-Host "✅ App: $($app.displayName)" -ForegroundColor Green

    # Look up group details
    Write-Host "🔍 Looking up group: $GroupId..." -ForegroundColor Cyan
    $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=id,displayName" -Method GET
    Write-Host "✅ Group: $($group.displayName)" -ForegroundColor Green

    # Retrieve existing assignments to merge
    Write-Host "🔍 Retrieving existing app assignments..." -ForegroundColor Cyan
    $existingResponse = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$AppId/assignments" -Method GET
    $existingAssignments = $existingResponse.value

    # Check for duplicate assignment
    $duplicateCheck = $existingAssignments | Where-Object {
        $_.target.groupId -eq $GroupId -and $_.intent -eq $Intent
    }
    if ($duplicateCheck) {
        Write-Host "ℹ️  App '$($app.displayName)' is already assigned to group '$($group.displayName)' with intent '$Intent'." -ForegroundColor Yellow
        exit 0
    }

    # Build new assignment object
    $targetType = if ($ExcludeGroup) {
        '#microsoft.graph.exclusionGroupAssignmentTarget'
    } else {
        '#microsoft.graph.groupAssignmentTarget'
    }

    $newAssignment = @{
        '@odata.type' = '#microsoft.graph.mobileAppAssignment'
        intent        = $Intent
        target        = @{
            '@odata.type' = $targetType
            groupId       = $GroupId
        }
    }

    if ($InstallTimeSettings -and $Intent -eq 'required') {
        $newAssignment['settings'] = @{
            '@odata.type'        = '#microsoft.graph.win32LobAppAssignmentSettings'
            installTimeSettings  = @{
                deadlineDateTime = $InstallTimeSettings
                useLocalTime     = $false
            }
        }
    }

    # Build final assignments array (preserve existing + add new)
    $allAssignments = @($existingAssignments) + @($newAssignment)
    $body = @{ mobileAppAssignments = $allAssignments } | ConvertTo-Json -Depth 10

    # Display assignment summary
    Write-Host "`n📋 Assignment Configuration:" -ForegroundColor Yellow
    Write-Host "   App:        $($app.displayName)" -ForegroundColor White
    Write-Host "   Group:      $($group.displayName)" -ForegroundColor White
    Write-Host "   Intent:     $Intent" -ForegroundColor White
    Write-Host "   Mode:       $(if ($ExcludeGroup) { 'Exclude' } else { 'Include' })" -ForegroundColor White
    if ($InstallTimeSettings) {
        Write-Host "   Deadline:   $InstallTimeSettings" -ForegroundColor White
    }

    # Submit the assignment
    Write-Host "`n🔧 Applying app assignment..." -ForegroundColor Cyan
    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps/$AppId/assign" `
        -Method POST `
        -Body $body `
        -ContentType "application/json"

    Write-Host "✅ App assignment applied successfully!" -ForegroundColor Green
    Write-Host "`n💡 Note: Policy distribution may take several minutes to reach devices." -ForegroundColor Yellow
}
catch {
    Write-Host "❌ Failed to assign Intune app: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
