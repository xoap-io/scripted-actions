<#
.SYNOPSIS
    Create a new Entra ID user account via the Microsoft Graph API.

.DESCRIPTION
    This script creates a new Entra ID (Azure AD) user account using the Microsoft Graph API.
    Supports setting the display name, UPN, password, department, job title, usage location,
    and whether the user must change their password at next sign-in.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: POST /users

.PARAMETER DisplayName
    The display name for the new user. Example: "Jane Doe"

.PARAMETER UserPrincipalName
    The User Principal Name (UPN) for the new user. Must be in email format.
    Example: jane.doe@contoso.com

.PARAMETER MailNickname
    The mail alias (nickname) for the user. No spaces or special characters.
    Example: jane.doe

.PARAMETER Password
    The initial password for the user as a SecureString.

.PARAMETER ForceChangePassword
    If specified, the user must change their password at next sign-in.

.PARAMETER AccountEnabled
    If specified, the account is created in an enabled state. Enabled by default.

.PARAMETER Department
    Optional. The department the user belongs to.

.PARAMETER JobTitle
    Optional. The user's job title.

.PARAMETER UsageLocation
    Optional. Two-letter ISO 3166 country code for the user's usage location.
    Required for assigning Microsoft 365 licenses.

.EXAMPLE
    .\msgraph-create-entra-user.ps1 -DisplayName "Jane Doe" -UserPrincipalName "jane.doe@contoso.com" -MailNickname "jane.doe" -Password (Read-Host -AsSecureString "Password")
    Creates a new enabled user with a required password change at next sign-in.

.EXAMPLE
    .\msgraph-create-entra-user.ps1 -DisplayName "John Smith" -UserPrincipalName "john.smith@contoso.com" -MailNickname "john.smith" -Password (Read-Host -AsSecureString "Password") -Department "Engineering" -JobTitle "Developer" -UsageLocation "US" -AccountEnabled
    Creates a new enabled user with department, job title, and usage location set.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft Graph connection (pre-established by XOAP)
    Permissions: User.ReadWrite.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/user-post-users

.COMPONENT
    Microsoft Graph Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The display name for the new user")]
    [ValidateNotNullOrEmpty()]
    [string]$DisplayName,

    [Parameter(Mandatory = $true, HelpMessage = "The User Principal Name (UPN) in email format")]
    [ValidatePattern('^[^@\s]+@[^@\s]+\.[^@\s]+$')]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $true, HelpMessage = "The mail alias (nickname) with no spaces or special characters")]
    [ValidateNotNullOrEmpty()]
    [string]$MailNickname,

    [Parameter(Mandatory = $true, HelpMessage = "The initial password for the user as a SecureString")]
    [ValidateNotNull()]
    [SecureString]$Password,

    [Parameter(Mandatory = $false, HelpMessage = "Require the user to change password at next sign-in")]
    [switch]$ForceChangePassword,

    [Parameter(Mandatory = $false, HelpMessage = "Create the account in an enabled state")]
    [switch]$AccountEnabled,

    [Parameter(Mandatory = $false, HelpMessage = "The department the user belongs to")]
    [string]$Department,

    [Parameter(Mandatory = $false, HelpMessage = "The user's job title")]
    [string]$JobTitle,

    [Parameter(Mandatory = $false, HelpMessage = "Two-letter ISO 3166 country code for usage location")]
    [ValidateLength(2, 2)]
    [string]$UsageLocation
)

$ErrorActionPreference = 'Stop'

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "👤 Entra ID User Creation" -ForegroundColor Blue
    Write-Host "=========================" -ForegroundColor Blue

    # Convert SecureString password to plain text for the API body
    $plainPassword = [System.Net.NetworkCredential]::new('', $Password).Password

    # Build the request body
    $body = @{
        displayName       = $DisplayName
        userPrincipalName = $UserPrincipalName
        mailNickname      = $MailNickname
        accountEnabled    = $AccountEnabled.IsPresent
        passwordProfile   = @{
            password                      = $plainPassword
            forceChangePasswordNextSignIn = $ForceChangePassword.IsPresent
        }
    }

    if ($Department)     { $body['department']     = $Department }
    if ($JobTitle)       { $body['jobTitle']        = $JobTitle }
    if ($UsageLocation)  { $body['usageLocation']   = $UsageLocation }

    Write-Host "🔧 Creating user: $DisplayName ($UserPrincipalName)..." -ForegroundColor Cyan

    $newUser = Invoke-MgGraphRequest -Uri "$GraphBase/users" -Method POST -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json"

    Write-Host "✅ User created successfully" -ForegroundColor Green
    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "   Object ID:       $($newUser.id)" -ForegroundColor White
    Write-Host "   Display Name:    $($newUser.displayName)" -ForegroundColor White
    Write-Host "   UPN:             $($newUser.userPrincipalName)" -ForegroundColor White
    Write-Host "   Account Enabled: $($newUser.accountEnabled)" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Assign the user a license if required (usageLocation must be set)" -ForegroundColor White
    Write-Host "   - Add the user to relevant groups and roles" -ForegroundColor White
    Write-Host "   - Verify the user can sign in at https://myaccount.microsoft.com" -ForegroundColor White
}
catch {
    Write-Host "❌ Failed to create Entra ID user: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
