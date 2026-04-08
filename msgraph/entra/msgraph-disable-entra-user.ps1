<#
.SYNOPSIS
    Enable or disable an Entra ID user account via the Microsoft Graph API.

.DESCRIPTION
    This script enables or disables an Entra ID (Azure AD) user account using the Microsoft
    Graph API. The account state is controlled by the AccountEnabled parameter.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: PATCH /users/{id}

.PARAMETER UserPrincipalName
    The User Principal Name (UPN) of the user to modify.
    Example: user@contoso.com

.PARAMETER UserId
    The Object ID (GUID) of the user. Can be used instead of UserPrincipalName.

.PARAMETER AccountEnabled
    Set to $true to enable the account, or $false to disable it.

.PARAMETER Force
    Skip the confirmation prompt before making changes.

.EXAMPLE
    .\msgraph-disable-entra-user.ps1 -UserPrincipalName "user@contoso.com" -AccountEnabled $false
    Disables the specified user account after confirmation.

.EXAMPLE
    .\msgraph-disable-entra-user.ps1 -UserPrincipalName "user@contoso.com" -AccountEnabled $true -Force
    Enables the specified user account without a confirmation prompt.

.EXAMPLE
    .\msgraph-disable-entra-user.ps1 -UserId "00000000-0000-0000-0000-000000000000" -AccountEnabled $false
    Disables the user identified by Object ID.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: User.EnableDisableAccount.All (Application), User.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/user-update

.COMPONENT
    Microsoft Graph, Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "User Principal Name of the target user")]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $false, HelpMessage = "Object ID of the target user")]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$UserId,

    [Parameter(Mandatory = $true, HelpMessage = "Set to true to enable or false to disable the account")]
    [bool]$AccountEnabled,

    [Parameter(Mandatory = $false, HelpMessage = "Skip confirmation prompt")]
    [switch]$Force
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Validate that at least one identifier is provided
if (-not $UserPrincipalName -and -not $UserId) {
    Write-Host "❌ Either -UserPrincipalName or -UserId must be specified." -ForegroundColor Red
    exit 1
}

try {
    $action = if ($AccountEnabled) { "enable" } else { "disable" }
    $actionPast = if ($AccountEnabled) { "enabled" } else { "disabled" }

    Write-Host "👤 Entra ID User Account Management" -ForegroundColor Blue
    Write-Host "=====================================" -ForegroundColor Blue

    # Resolve user identifier
    $identifier = if ($UserId) { $UserId } else { $UserPrincipalName }

    # Retrieve current user info
    Write-Host "🔍 Looking up user: $identifier..." -ForegroundColor Cyan
    $user = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$identifier`?`$select=id,displayName,userPrincipalName,accountEnabled" -Method GET

    Write-Host "✅ Found user: $($user.displayName) ($($user.userPrincipalName))" -ForegroundColor Green
    Write-Host "   Object ID:       $($user.id)" -ForegroundColor White
    Write-Host "   Current Status:  $(if ($user.accountEnabled) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White
    Write-Host "   Target Status:   $(if ($AccountEnabled) { 'Enabled' } else { 'Disabled' })" -ForegroundColor White

    # Check if already in desired state
    if ($user.accountEnabled -eq $AccountEnabled) {
        Write-Host "`nℹ️  Account is already $(if ($AccountEnabled) { 'enabled' }  else { 'disabled' }). No change required." -ForegroundColor Yellow
        exit 0
    }

    # Confirmation prompt
    if (-not $Force) {
        Write-Host "`n⚠️  You are about to $action the account for: $($user.displayName)" -ForegroundColor Yellow
        $confirmation = Read-Host "Type 'YES' to confirm or anything else to cancel"
        if ($confirmation -ne 'YES') {
            Write-Host "❌ Operation cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    # Apply the change
    Write-Host "`n🔧 Updating account status..." -ForegroundColor Cyan
    $body = @{ accountEnabled = $AccountEnabled } | ConvertTo-Json

    Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)" -Method PATCH -Body $body -ContentType "application/json"

    Write-Host "✅ Account successfully $actionPast for: $($user.displayName)" -ForegroundColor Green

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    if (-not $AccountEnabled) {
        Write-Host "   - Active sessions for this user may persist until token expiry" -ForegroundColor White
        Write-Host "   - Consider revoking sign-in sessions: Revoke-MgUserSignInSession" -ForegroundColor White
    }
    else {
        Write-Host "   - The user can now sign in with their existing credentials" -ForegroundColor White
        Write-Host "   - Verify the user's licenses and group memberships are still in place" -ForegroundColor White
    }
}
catch {
    Write-Host "❌ Failed to update user account: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
