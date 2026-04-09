<#
.SYNOPSIS
    Update properties of an existing Entra ID user via the Microsoft Graph API.

.DESCRIPTION
    This script updates one or more properties of an existing Entra ID (Azure AD) user using
    the Microsoft Graph API. Only properties that are explicitly provided will be sent in the
    PATCH request — omitted parameters are not overwritten.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: PATCH /users/{id}

.PARAMETER UserPrincipalNameOrId
    The User Principal Name (UPN) or Object ID (GUID) of the user to update.
    Example: user@contoso.com or 00000000-0000-0000-0000-000000000000

.PARAMETER DisplayName
    Optional. The new display name for the user.

.PARAMETER Department
    Optional. The department to assign to the user.

.PARAMETER JobTitle
    Optional. The job title to assign to the user.

.PARAMETER UsageLocation
    Optional. Two-letter ISO 3166 country code for the user's usage location.

.PARAMETER OfficeLocation
    Optional. The office location of the user.

.PARAMETER MobilePhone
    Optional. The user's mobile phone number.

.EXAMPLE
    .\msgraph-update-entra-user.ps1 -UserPrincipalNameOrId "user@contoso.com" -Department "Engineering" -JobTitle "Senior Developer"
    Updates the department and job title for the specified user.

.EXAMPLE
    .\msgraph-update-entra-user.ps1 -UserPrincipalNameOrId "00000000-0000-0000-0000-000000000000" -DisplayName "Jane Smith" -UsageLocation "GB" -MobilePhone "+44 7700 900000"
    Updates display name, usage location, and mobile phone by Object ID.

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
    https://learn.microsoft.com/en-us/graph/api/user-update

.COMPONENT
    Microsoft Graph Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The UPN or Object ID of the user to update")]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalNameOrId,

    [Parameter(Mandatory = $false, HelpMessage = "The new display name for the user")]
    [string]$DisplayName,

    [Parameter(Mandatory = $false, HelpMessage = "The department to assign to the user")]
    [string]$Department,

    [Parameter(Mandatory = $false, HelpMessage = "The job title to assign to the user")]
    [string]$JobTitle,

    [Parameter(Mandatory = $false, HelpMessage = "Two-letter ISO 3166 country code for usage location")]
    [ValidateLength(2, 2)]
    [string]$UsageLocation,

    [Parameter(Mandatory = $false, HelpMessage = "The office location of the user")]
    [string]$OfficeLocation,

    [Parameter(Mandatory = $false, HelpMessage = "The user's mobile phone number")]
    [string]$MobilePhone
)

$ErrorActionPreference = 'Stop'

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "👤 Entra ID User Update" -ForegroundColor Blue
    Write-Host "=======================" -ForegroundColor Blue

    # Resolve the user
    Write-Host "🔍 Looking up user: $UserPrincipalNameOrId..." -ForegroundColor Cyan
    $user = Invoke-MgGraphRequest -Uri "$GraphBase/users/$([Uri]::EscapeDataString($UserPrincipalNameOrId))?`$select=id,displayName,userPrincipalName,department,jobTitle,usageLocation,officeLocation,mobilePhone" -Method GET

    Write-Host "✅ Found user: $($user.displayName) ($($user.userPrincipalName))" -ForegroundColor Green
    Write-Host "   Object ID: $($user.id)" -ForegroundColor White

    # Build patch body — only include provided properties
    $body = @{}
    if ($PSBoundParameters.ContainsKey('DisplayName'))    { $body['displayName']    = $DisplayName }
    if ($PSBoundParameters.ContainsKey('Department'))     { $body['department']     = $Department }
    if ($PSBoundParameters.ContainsKey('JobTitle'))       { $body['jobTitle']       = $JobTitle }
    if ($PSBoundParameters.ContainsKey('UsageLocation'))  { $body['usageLocation']  = $UsageLocation }
    if ($PSBoundParameters.ContainsKey('OfficeLocation')) { $body['officeLocation'] = $OfficeLocation }
    if ($PSBoundParameters.ContainsKey('MobilePhone'))    { $body['mobilePhone']    = $MobilePhone }

    if ($body.Count -eq 0) {
        Write-Host "ℹ️  No properties specified for update. Nothing to do." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "`n🔧 Applying updates..." -ForegroundColor Cyan
    $body.Keys | ForEach-Object { Write-Host "   $_: $($body[$_])" -ForegroundColor White }

    Invoke-MgGraphRequest -Uri "$GraphBase/users/$($user.id)" -Method PATCH -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json"

    Write-Host "`n✅ User updated successfully: $($user.displayName)" -ForegroundColor Green
}
catch {
    Write-Host "❌ Failed to update Entra ID user: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
