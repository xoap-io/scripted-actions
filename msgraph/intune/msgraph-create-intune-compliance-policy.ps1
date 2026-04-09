<#
.SYNOPSIS
    Create a device compliance policy in Microsoft Intune via the Microsoft Graph API.

.DESCRIPTION
    This script creates a new device compliance policy in Microsoft Intune using the Microsoft
    Graph API. Supports Windows 10/11, iOS, Android, and macOS platforms with configurable
    security requirements such as BitLocker, Secure Boot, password requirements, and encryption.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint:
      POST /deviceManagement/deviceCompliancePolicies

.PARAMETER PolicyName
    The display name for the new compliance policy.

.PARAMETER Platform
    The platform the policy targets. Valid values: Windows10, iOS, Android, macOS.
    Defaults to Windows10.

.PARAMETER RequireBitLocker
    If specified, BitLocker is required on Windows devices.

.PARAMETER RequireSecureBoot
    If specified, Secure Boot is required on Windows devices.

.PARAMETER MinimumOsVersion
    Optional. Minimum OS version required for compliance. Example: "10.0.19041"

.PARAMETER PasswordRequired
    If specified, a password is required on the device.

.PARAMETER PasswordMinLength
    Optional. Minimum password length. Valid range: 4–16.

.PARAMETER StorageRequireEncryption
    If specified, storage encryption is required.

.PARAMETER Description
    Optional. A description for the compliance policy.

.EXAMPLE
    .\msgraph-create-intune-compliance-policy.ps1 -PolicyName "Windows-Baseline-Compliance" -RequireBitLocker -RequireSecureBoot -PasswordRequired -PasswordMinLength 8
    Creates a Windows 10/11 compliance policy requiring BitLocker, Secure Boot, and a password of at least 8 characters.

.EXAMPLE
    .\msgraph-create-intune-compliance-policy.ps1 -PolicyName "iOS-Corporate-Compliance" -Platform iOS -PasswordRequired -PasswordMinLength 6 -StorageRequireEncryption -MinimumOsVersion "16.0"
    Creates an iOS compliance policy with password and encryption requirements.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft Graph connection (pre-established by XOAP)
    Permissions: DeviceManagementConfiguration.ReadWrite.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-windows10compliancepolicy-create

.COMPONENT
    Microsoft Graph Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The display name for the new compliance policy")]
    [ValidateNotNullOrEmpty()]
    [string]$PolicyName,

    [Parameter(Mandatory = $false, HelpMessage = "The target platform for the policy")]
    [ValidateSet('Windows10', 'iOS', 'Android', 'macOS')]
    [string]$Platform = 'Windows10',

    [Parameter(Mandatory = $false, HelpMessage = "Require BitLocker on Windows devices")]
    [switch]$RequireBitLocker,

    [Parameter(Mandatory = $false, HelpMessage = "Require Secure Boot on Windows devices")]
    [switch]$RequireSecureBoot,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum OS version required for compliance")]
    [string]$MinimumOsVersion,

    [Parameter(Mandatory = $false, HelpMessage = "Require a password on the device")]
    [switch]$PasswordRequired,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum password length (4-16)")]
    [ValidateRange(4, 16)]
    [int]$PasswordMinLength,

    [Parameter(Mandatory = $false, HelpMessage = "Require storage encryption on the device")]
    [switch]$StorageRequireEncryption,

    [Parameter(Mandatory = $false, HelpMessage = "A description for the compliance policy")]
    [string]$Description
)

$ErrorActionPreference = 'Stop'

try {
    $GraphBase = 'https://graph.microsoft.com/v1.0'

    Write-Host "🛡️  Intune Compliance Policy Creation" -ForegroundColor Blue
    Write-Host "======================================" -ForegroundColor Blue
    Write-Host "   Policy Name: $PolicyName" -ForegroundColor White
    Write-Host "   Platform:    $Platform" -ForegroundColor White

    # Map platform to OData type
    $odataType = switch ($Platform) {
        'Windows10' { '#microsoft.graph.windows10CompliancePolicy' }
        'iOS'       { '#microsoft.graph.iosCompliancePolicy' }
        'Android'   { '#microsoft.graph.androidCompliancePolicy' }
        'macOS'     { '#microsoft.graph.macOSCompliancePolicy' }
    }

    $body = @{
        '@odata.type' = $odataType
        displayName   = $PolicyName
    }

    if ($Description)            { $body['description']               = $Description }
    if ($MinimumOsVersion)       { $body['osMinimumVersion']          = $MinimumOsVersion }
    if ($StorageRequireEncryption.IsPresent) { $body['storageRequireEncryption'] = $true }
    if ($PasswordRequired.IsPresent)         { $body['passwordRequired']         = $true }
    if ($PSBoundParameters.ContainsKey('PasswordMinLength')) { $body['passwordMinimumLength'] = $PasswordMinLength }

    # Windows-specific settings
    if ($Platform -eq 'Windows10') {
        if ($RequireBitLocker.IsPresent)  { $body['bitLockerEnabled']  = $true }
        if ($RequireSecureBoot.IsPresent) { $body['secureBootEnabled'] = $true }
    }

    Write-Host "`n🔧 Creating compliance policy..." -ForegroundColor Cyan

    $policy = Invoke-MgGraphRequest -Uri "$GraphBase/deviceManagement/deviceCompliancePolicies" -Method POST -Body ($body | ConvertTo-Json -Depth 5) -ContentType "application/json"

    Write-Host "✅ Compliance policy created successfully" -ForegroundColor Green
    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "   Policy Id:   $($policy.id)" -ForegroundColor White
    Write-Host "   Policy Name: $($policy.displayName)" -ForegroundColor White
    Write-Host "   Platform:    $Platform" -ForegroundColor White
    Write-Host "   Created:     $($policy.createdDateTime)" -ForegroundColor White

    Write-Host "`n💡 Next Steps:" -ForegroundColor Yellow
    Write-Host "   - Assign the policy to an Entra ID group or all devices" -ForegroundColor White
    Write-Host "   - Configure a notification message template for non-compliant devices" -ForegroundColor White
    Write-Host "   - Set a grace period under 'Actions for non-compliance' in the portal" -ForegroundColor White
}
catch {
    Write-Host "❌ Failed to create compliance policy: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
