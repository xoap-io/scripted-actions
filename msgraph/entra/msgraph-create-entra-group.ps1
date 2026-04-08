<#
.SYNOPSIS
    Create a new Entra ID group via the Microsoft Graph API.

.DESCRIPTION
    This script creates a new Security or Microsoft 365 group in Entra ID (Azure AD)
    using the Microsoft Graph API. Supports static and dynamic membership groups.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: POST /groups

.PARAMETER DisplayName
    Display name for the new group.

.PARAMETER MailNickname
    Mail alias for the group. Required for all group types (used as identifier even for
    non-mail-enabled groups). Must be unique within the tenant. No spaces allowed.

.PARAMETER GroupType
    Type of group to create. Valid values: Security, Microsoft365.

.PARAMETER Description
    Optional description for the group.

.PARAMETER MembershipRule
    Dynamic membership rule expression. When provided, creates a dynamic group.
    Example: "(user.department -eq \"IT\")"

.PARAMETER Owners
    Comma-separated list of user UPNs to assign as group owners.

.EXAMPLE
    .\msgraph-create-entra-group.ps1 -DisplayName "SG-IT-Admins" -MailNickname "sg-it-admins" -GroupType Security
    Creates a static security group.

.EXAMPLE
    .\msgraph-create-entra-group.ps1 -DisplayName "M365-Engineering" -MailNickname "m365-engineering" -GroupType Microsoft365 -Description "Engineering team collaboration"
    Creates a Microsoft 365 group with a description.

.EXAMPLE
    .\msgraph-create-entra-group.ps1 -DisplayName "SG-Dyn-IT" -MailNickname "sg-dyn-it" -GroupType Security -MembershipRule '(user.department -eq "IT")'
    Creates a dynamic security group based on department.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: Group.ReadWrite.All (Application)
    Dynamic groups additionally require: Directory.ReadWrite.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/group-post-groups

.COMPONENT
    Microsoft Graph, Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Display name for the group")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 256)]
    [string]$DisplayName,

    [Parameter(Mandatory = $true, HelpMessage = "Mail alias/nickname (no spaces, unique in tenant)")]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern('^[a-zA-Z0-9._-]+$')]
    [ValidateLength(1, 64)]
    [string]$MailNickname,

    [Parameter(Mandatory = $true, HelpMessage = "Group type to create")]
    [ValidateSet('Security', 'Microsoft365')]
    [string]$GroupType,

    [Parameter(Mandatory = $false, HelpMessage = "Group description")]
    [ValidateLength(0, 1024)]
    [string]$Description,

    [Parameter(Mandatory = $false, HelpMessage = "Dynamic membership rule expression")]
    [string]$MembershipRule,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated UPNs to assign as owners")]
    [string]$Owners
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    Write-Host "➕ Create Entra ID Group" -ForegroundColor Blue
    Write-Host "========================" -ForegroundColor Blue

    # Check for existing group with same display name
    Write-Host "🔍 Checking for existing groups with display name '$DisplayName'..." -ForegroundColor Cyan
    $checkFilter = [Uri]::EscapeDataString("displayName eq '$DisplayName'")
    $existing = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups?`$filter=$checkFilter&`$select=id,displayName" -Method GET

    if ($existing.value.Count -gt 0) {
        Write-Host "⚠️  A group named '$DisplayName' already exists (ID: $($existing.value[0].id))." -ForegroundColor Yellow
        Write-Host "   Proceeding will create a duplicate display name." -ForegroundColor Yellow
        $continue = Read-Host "Continue anyway? (y/N)"
        if ($continue -ne 'y' -and $continue -ne 'Y') {
            Write-Host "❌ Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Build group body
    $isDynamic = [bool]$MembershipRule
    $isM365 = $GroupType -eq 'Microsoft365'

    $groupBody = [ordered]@{
        displayName     = $DisplayName
        mailNickname    = $MailNickname
        mailEnabled     = $isM365
        securityEnabled = -not $isM365 -or $true   # Security groups are always securityEnabled
        groupTypes      = @()
    }

    # Microsoft 365 groups require 'Unified' in groupTypes
    if ($isM365) { $groupBody['groupTypes'] = @('Unified') }

    # Dynamic groups require DynamicMembership in groupTypes
    if ($isDynamic) {
        $groupBody['groupTypes'] += 'DynamicMembership'
        $groupBody['membershipRule'] = $MembershipRule
        $groupBody['membershipRuleProcessingState'] = 'On'
    }

    if ($Description) { $groupBody['description'] = $Description }

    # Resolve owner object IDs
    if ($Owners) {
        Write-Host "🔍 Resolving owner accounts..." -ForegroundColor Cyan
        $ownerIds = @()
        foreach ($upn in ($Owners -split ',').Trim()) {
            $encodedUpn = [Uri]::EscapeDataString($upn)
            $ownerUser = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$encodedUpn`?`$select=id,displayName" -Method GET
            Write-Host "   ✅ Resolved owner: $($ownerUser.displayName) ($upn)" -ForegroundColor Green
            $ownerIds += "https://graph.microsoft.com/v1.0/users/$($ownerUser.id)"
        }
        $groupBody['owners@odata.bind'] = $ownerIds
    }

    # Display planned configuration
    Write-Host "`n📋 Group Configuration:" -ForegroundColor Yellow
    Write-Host "   Display Name:  $DisplayName" -ForegroundColor White
    Write-Host "   Mail Nickname: $MailNickname" -ForegroundColor White
    Write-Host "   Group Type:    $GroupType" -ForegroundColor White
    Write-Host "   Dynamic:       $(if ($isDynamic) { 'Yes' } else { 'No' })" -ForegroundColor White
    if ($Description) { Write-Host "   Description:   $Description" -ForegroundColor White }
    if ($isDynamic)   { Write-Host "   Rule:          $MembershipRule" -ForegroundColor White }

    # Create the group
    Write-Host "`n🔧 Creating group..." -ForegroundColor Cyan
    $newGroup = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/groups" `
        -Method POST `
        -Body ($groupBody | ConvertTo-Json -Depth 5) `
        -ContentType "application/json"

    Write-Host "✅ Group created successfully!" -ForegroundColor Green
    Write-Host "`n📝 Group Details:" -ForegroundColor Yellow
    Write-Host "   Object ID:   $($newGroup.id)" -ForegroundColor White
    Write-Host "   Display Name: $($newGroup.displayName)" -ForegroundColor White
    Write-Host "   Type:         $GroupType" -ForegroundColor White
    Write-Host "   Created:      $($newGroup.createdDateTime)" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Add members using: .\msgraph-add-entra-group-member.ps1 -GroupId '$($newGroup.id)'" -ForegroundColor White
    if ($isDynamic) {
        Write-Host "   - Dynamic membership processing may take a few minutes to populate" -ForegroundColor White
    }
}
catch {
    Write-Host "❌ Failed to create Entra ID group: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
