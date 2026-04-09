<#
.SYNOPSIS
    Assign a directory role to an Entra ID user via the Microsoft Graph API.

.DESCRIPTION
    This script assigns an Entra ID (Azure AD) directory role to a specified user using the
    Microsoft Graph API. The role is resolved by display name, and the user is resolved by
    UPN or Object ID. Assigning the Global Administrator role requires the -Force switch as
    an additional safety guard.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoints:
      GET /directoryRoles
      POST /directoryRoles/{roleId}/members/$ref

.PARAMETER UserPrincipalNameOrId
    The User Principal Name (UPN) or Object ID (GUID) of the user to assign the role to.
    Example: user@contoso.com or 00000000-0000-0000-0000-000000000000

.PARAMETER RoleName
    The display name of the directory role to assign.
    Example: "Global Administrator", "User Administrator", "Helpdesk Administrator"

.PARAMETER Force
    Required when assigning the Global Administrator role. Also skips the confirmation prompt.

.EXAMPLE
    .\msgraph-assign-entra-role.ps1 -UserPrincipalNameOrId "user@contoso.com" -RoleName "Helpdesk Administrator"
    Assigns the Helpdesk Administrator role to the specified user after confirmation.

.EXAMPLE
    .\msgraph-assign-entra-role.ps1 -UserPrincipalNameOrId "00000000-0000-0000-0000-000000000000" -RoleName "Global Administrator" -Force
    Assigns the Global Administrator role by Object ID, bypassing confirmation.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft Graph connection (pre-established by XOAP)
    Permissions: RoleManagement.ReadWrite.Directory (Application), User.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/directoryrole-post-members

.COMPONENT
    Microsoft Graph Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The UPN or Object ID of the user to assign the role to")]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalNameOrId,

    [Parameter(Mandatory = $true, HelpMessage = "The display name of the directory role to assign")]
    [ValidateNotNullOrEmpty()]
    [string]$RoleName,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt; required for Global Administrator assignment")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "🔐 Entra ID Directory Role Assignment" -ForegroundColor Blue
    Write-Host "======================================" -ForegroundColor Blue

    # Guard against accidental Global Administrator assignment
    if ($RoleName -eq 'Global Administrator' -and -not $Force) {
        Write-Host "❌ Assigning the 'Global Administrator' role is a privileged operation." -ForegroundColor Red
        Write-Host "   Re-run the script with -Force to confirm this assignment." -ForegroundColor Yellow
        exit 1
    }

    # Resolve user
    Write-Host "🔍 Looking up user: $UserPrincipalNameOrId..." -ForegroundColor Cyan
    $user = Invoke-MgGraphRequest -Uri "$GraphBase/users/$([Uri]::EscapeDataString($UserPrincipalNameOrId))?`$select=id,displayName,userPrincipalName" -Method GET
    Write-Host "✅ Found user: $($user.displayName) ($($user.userPrincipalName))" -ForegroundColor Green

    # Resolve directory role by display name
    Write-Host "🔍 Resolving role: $RoleName..." -ForegroundColor Cyan
    $rolesResponse = Invoke-MgGraphRequest -Uri "$GraphBase/directoryRoles?`$select=id,displayName,roleTemplateId" -Method GET
    $role = $rolesResponse.value | Where-Object { $_.displayName -eq $RoleName } | Select-Object -First 1

    if (-not $role) {
        # Role may not be activated yet — attempt to activate via roleTemplate
        Write-Host "⚠️  Role not yet activated. Searching role templates..." -ForegroundColor Yellow
        $templatesResponse = Invoke-MgGraphRequest -Uri "$GraphBase/directoryRoleTemplates?`$select=id,displayName" -Method GET
        $template = $templatesResponse.value | Where-Object { $_.displayName -eq $RoleName } | Select-Object -First 1

        if (-not $template) {
            Write-Host "❌ Role '$RoleName' not found. Check the role display name and try again." -ForegroundColor Red
            exit 1
        }

        Write-Host "🔧 Activating role template: $RoleName..." -ForegroundColor Cyan
        $activateBody = @{ roleTemplateId = $template.id } | ConvertTo-Json
        $role = Invoke-MgGraphRequest -Uri "$GraphBase/directoryRoles" -Method POST -Body $activateBody -ContentType "application/json"
    }

    Write-Host "✅ Found role: $($role.displayName) (Id: $($role.id))" -ForegroundColor Green

    # Confirmation prompt
    if (-not $Force) {
        Write-Host "`n⚠️  You are about to assign '$($role.displayName)' to $($user.displayName)." -ForegroundColor Yellow
        $confirmation = Read-Host "Type 'YES' to confirm or anything else to cancel"
        if ($confirmation -ne 'YES') {
            Write-Host "❌ Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Assign the role
    Write-Host "`n🔧 Assigning role '$($role.displayName)' to $($user.displayName)..." -ForegroundColor Cyan
    $refBody = @{ '@odata.id' = "$GraphBase/directoryObjects/$($user.id)" } | ConvertTo-Json
    Invoke-MgGraphRequest -Uri "$GraphBase/directoryRoles/$($role.id)/members/`$ref" -Method POST -Body $refBody -ContentType "application/json"

    Write-Host "✅ Role '$($role.displayName)' successfully assigned to $($user.displayName)" -ForegroundColor Green

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - The role is active immediately; no sign-out/sign-in required" -ForegroundColor White
    Write-Host "   - Review role assignments regularly for least-privilege compliance" -ForegroundColor White
}
catch {
    Write-Host "❌ Failed to assign directory role: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
