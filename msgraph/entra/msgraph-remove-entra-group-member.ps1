<#
.SYNOPSIS
    Remove a member from an Entra ID group via the Microsoft Graph API.

.DESCRIPTION
    This script removes a user or device from an Entra ID (Azure AD) group using the Microsoft
    Graph API. The group is resolved by display name or Object ID, and the member is resolved
    by UPN or Object ID. The script verifies group membership before attempting removal and
    requires explicit confirmation unless -Force is specified.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoints:
      GET /groups
      GET /groups/{id}/members
      DELETE /groups/{groupId}/members/{memberId}/$ref

.PARAMETER GroupNameOrId
    The display name or Object ID (GUID) of the group to remove the member from.

.PARAMETER MemberUserPrincipalNameOrId
    The User Principal Name (UPN) or Object ID (GUID) of the member to remove.

.PARAMETER Force
    Skip the confirmation prompt before removing the member.

.EXAMPLE
    .\msgraph-remove-entra-group-member.ps1 -GroupNameOrId "SG-IT-Admins" -MemberUserPrincipalNameOrId "user@contoso.com"
    Removes the specified user from the group after a confirmation prompt.

.EXAMPLE
    .\msgraph-remove-entra-group-member.ps1 -GroupNameOrId "00000000-0000-0000-0000-000000000000" -MemberUserPrincipalNameOrId "11111111-1111-1111-1111-111111111111" -Force
    Removes the specified member by Object IDs without a confirmation prompt.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft Graph connection (pre-established by XOAP)
    Permissions: GroupMember.ReadWrite.All (Application), User.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/group-delete-members

.COMPONENT
    Microsoft Graph Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The display name or Object ID of the group")]
    [ValidateNotNullOrEmpty()]
    [string]$GroupNameOrId,

    [Parameter(Mandatory = $true, HelpMessage = "The UPN or Object ID of the member to remove")]
    [ValidateNotNullOrEmpty()]
    [string]$MemberUserPrincipalNameOrId,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "👥 Entra ID Group Member Removal" -ForegroundColor Blue
    Write-Host "=================================" -ForegroundColor Blue

    # Resolve group — try direct GUID lookup first, then search by displayName
    Write-Host "🔍 Resolving group: $GroupNameOrId..." -ForegroundColor Cyan
    $isGuid = $GroupNameOrId -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

    if ($isGuid) {
        $group = Invoke-MgGraphRequest -Uri "$GraphBase/groups/$GroupNameOrId`?`$select=id,displayName" -Method GET
    }
    else {
        $groupsResponse = Invoke-MgGraphRequest -Uri "$GraphBase/groups?`$filter=displayName eq '$([Uri]::EscapeDataString($GroupNameOrId))'&`$select=id,displayName" -Method GET
        $group = $groupsResponse.value | Select-Object -First 1
        if (-not $group) {
            Write-Host "❌ No group found with display name: $GroupNameOrId" -ForegroundColor Red
            exit 1
        }
    }
    Write-Host "✅ Found group: $($group.displayName) (Id: $($group.id))" -ForegroundColor Green

    # Resolve member
    Write-Host "🔍 Resolving member: $MemberUserPrincipalNameOrId..." -ForegroundColor Cyan
    $member = Invoke-MgGraphRequest -Uri "$GraphBase/users/$([Uri]::EscapeDataString($MemberUserPrincipalNameOrId))?`$select=id,displayName,userPrincipalName" -Method GET
    Write-Host "✅ Found member: $($member.displayName) ($($member.userPrincipalName))" -ForegroundColor Green

    # Verify membership
    Write-Host "🔍 Verifying group membership..." -ForegroundColor Cyan
    $membersResponse = Invoke-MgGraphRequest -Uri "$GraphBase/groups/$($group.id)/members?`$select=id" -Method GET
    $isMember = $membersResponse.value | Where-Object { $_.id -eq $member.id }

    if (-not $isMember) {
        Write-Host "ℹ️  $($member.displayName) is not a member of '$($group.displayName)'. Nothing to remove." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "✅ Membership confirmed." -ForegroundColor Green

    # Confirmation prompt
    if (-not $Force) {
        Write-Host "`n⚠️  You are about to remove $($member.displayName) from group '$($group.displayName)'." -ForegroundColor Yellow
        $confirmation = Read-Host "Type 'YES' to confirm or anything else to cancel"
        if ($confirmation -ne 'YES') {
            Write-Host "❌ Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Remove member
    Write-Host "`n🔧 Removing $($member.displayName) from '$($group.displayName)'..." -ForegroundColor Cyan
    Invoke-MgGraphRequest -Uri "$GraphBase/groups/$($group.id)/members/$($member.id)/`$ref" -Method DELETE

    Write-Host "✅ $($member.displayName) successfully removed from '$($group.displayName)'" -ForegroundColor Green

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Group-based policy or license assignments may take a few minutes to update" -ForegroundColor White
    Write-Host "   - Verify the user no longer has access granted via this group" -ForegroundColor White
}
catch {
    Write-Host "❌ Failed to remove group member: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
