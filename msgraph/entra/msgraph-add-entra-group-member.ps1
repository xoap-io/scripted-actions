<#
.SYNOPSIS
    Add a user or device to an Entra ID group via the Microsoft Graph API.

.DESCRIPTION
    This script adds a user or device as a member of an Entra ID (Azure AD) group
    using the Microsoft Graph API. The target group must be a static membership group;
    dynamic groups do not support direct member additions.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: POST /groups/{id}/members/$ref

.PARAMETER GroupId
    Object ID (GUID) of the target group.

.PARAMETER MemberUserPrincipalName
    UPN of the user to add as a member. Use this or MemberObjectId.

.PARAMETER MemberObjectId
    Object ID of the user or device to add. Use this or MemberUserPrincipalName.

.PARAMETER MemberType
    Whether the member is a User or Device. Used when MemberObjectId is specified.
    Valid values: User, Device.

.EXAMPLE
    .\msgraph-add-entra-group-member.ps1 -GroupId "00000000-0000-0000-0000-000000000000" -MemberUserPrincipalName "user@contoso.com"
    Adds a user to the specified group by UPN.

.EXAMPLE
    .\msgraph-add-entra-group-member.ps1 -GroupId "00000000-0000-0000-0000-000000000000" -MemberObjectId "11111111-1111-1111-1111-111111111111" -MemberType User
    Adds a user by Object ID.

.EXAMPLE
    .\msgraph-add-entra-group-member.ps1 -GroupId "00000000-0000-0000-0000-000000000000" -MemberObjectId "22222222-2222-2222-2222-222222222222" -MemberType Device
    Adds a device by Object ID.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: GroupMember.ReadWrite.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/group-post-members

.COMPONENT
    Microsoft Graph, Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Object ID of the target group")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$GroupId,

    [Parameter(Mandatory = $false, HelpMessage = "UPN of the user to add")]
    [ValidateNotNullOrEmpty()]
    [string]$MemberUserPrincipalName,

    [Parameter(Mandatory = $false, HelpMessage = "Object ID of the user or device to add")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$MemberObjectId,

    [Parameter(Mandatory = $false, HelpMessage = "Type of the member object")]
    [ValidateSet('User', 'Device')]
    [string]$MemberType = 'User'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Validate that at least one member identifier is provided
if (-not $MemberUserPrincipalName -and -not $MemberObjectId) {
    Write-Host "❌ Either -MemberUserPrincipalName or -MemberObjectId must be specified." -ForegroundColor Red
    exit 1
}

try {
    Write-Host "➕ Add Member to Entra ID Group" -ForegroundColor Blue
    Write-Host "================================" -ForegroundColor Blue

    # Resolve group info
    Write-Host "🔍 Looking up group: $GroupId..." -ForegroundColor Cyan
    $group = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId`?`$select=id,displayName,groupTypes,membershipRule" -Method GET

    if ($group.membershipRule) {
        Write-Host "❌ Group '$($group.displayName)' is a dynamic group. Members cannot be added directly." -ForegroundColor Red
        exit 1
    }
    Write-Host "✅ Group: $($group.displayName)" -ForegroundColor Green

    # Resolve member object ID
    if ($MemberUserPrincipalName) {
        Write-Host "🔍 Looking up user: $MemberUserPrincipalName..." -ForegroundColor Cyan
        $member = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$MemberUserPrincipalName`?`$select=id,displayName,userPrincipalName" -Method GET
        $resolvedId = $member.id
        $memberLabel = "$($member.displayName) ($($member.userPrincipalName))"
        $odataType = "#microsoft.graph.user"
    }
    else {
        $resolvedId = $MemberObjectId
        $memberLabel = "$MemberType: $MemberObjectId"
        $odataType = if ($MemberType -eq 'Device') { "#microsoft.graph.device" } else { "#microsoft.graph.user" }
    }

    Write-Host "✅ Member resolved: $memberLabel" -ForegroundColor Green

    # Check if already a member
    Write-Host "🔍 Checking existing membership..." -ForegroundColor Cyan
    try {
        $existing = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members/$resolvedId" -Method GET
        Write-Host "ℹ️  '$memberLabel' is already a member of '$($group.displayName)'." -ForegroundColor Yellow
        exit 0
    }
    catch {
        # 404 means not a member — expected, proceed
        if ($_.Exception.Message -notmatch '404|Request_ResourceNotFound') { throw }
    }

    # Add member
    Write-Host "🔧 Adding member to group..." -ForegroundColor Cyan
    $body = @{
        '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$resolvedId"
    } | ConvertTo-Json

    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members/`$ref" `
        -Method POST `
        -Body $body `
        -ContentType "application/json"

    Write-Host "✅ Successfully added '$memberLabel' to group '$($group.displayName)'" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to add group member: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
