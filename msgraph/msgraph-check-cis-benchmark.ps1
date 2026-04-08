<#
.SYNOPSIS
    Check and optionally remediate CIS Benchmark settings for Microsoft Entra ID
    and Microsoft Intune using the Microsoft Graph API.

.DESCRIPTION
    This script evaluates your tenant against a curated set of controls from the
    CIS Microsoft 365 Foundations Benchmark (v3.1) and reports a PASS/FAIL status
    for each. When -Remediate is specified, controls that can be safely adjusted via
    the Graph API are patched to their compliant state.

    Checks are grouped into two categories:
      Entra  — Identity, Conditional Access, authorization, and consent policies
      Intune — MDM authority, compliance policies, and Defender integration

    Each control includes the CIS control ID, a description, the current value,
    and a remediation recommendation. Results are optionally exported to CSV or JSON.

    Uses the Microsoft Graph API via Invoke-MgGraphRequest (no authentication code —
    XOAP handles the connection using an App Registration).

.PARAMETER Scope
    Which CIS controls to evaluate. Accepts: All, Entra, Intune. Defaults to All.

.PARAMETER Remediate
    Attempt to patch non-compliant settings that can be safely remediated via the
    Graph API. Controls that require manual action (e.g. Conditional Access policy
    creation, admin role assignments) are flagged but never modified automatically.

.PARAMETER WhatIf
    Show which settings would be remediated without making any changes. Requires
    -Remediate to have any effect.

.PARAMETER Force
    Skip confirmation prompts when applying remediations.

.PARAMETER ExportFormat
    Export results to a timestamped file in the current directory.
    Accepts: CSV, JSON, None. Defaults to CSV.

.EXAMPLE
    .\msgraph-check-cis-benchmark.ps1
    Checks all CIS controls and exports results to a CSV file.

.EXAMPLE
    .\msgraph-check-cis-benchmark.ps1 -Scope Entra -ExportFormat JSON
    Checks only Entra ID controls and exports results as JSON.

.EXAMPLE
    .\msgraph-check-cis-benchmark.ps1 -Remediate -Force
    Checks all controls and immediately remediates non-compliant automatable settings.

.EXAMPLE
    .\msgraph-check-cis-benchmark.ps1 -Remediate -WhatIf
    Shows which settings would be remediated without making any changes.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Reference: CIS Microsoft 365 Foundations Benchmark v3.1

    Required Graph API permissions (Application):
      Policy.Read.All                              — Read policies (CA, auth, consent)
      Policy.ReadWrite.Authorization               — Remediate authorization policy
      Policy.ReadWrite.ConsentRequest              — Remediate admin consent workflow
      Directory.Read.All                           — Read directory roles and members
      DeviceManagementServiceConfig.Read.All       — Read MDM authority
      DeviceManagementConfiguration.Read.All       — Read Intune compliance policies
      DeviceManagementManagedDevices.Read.All      — Read Intune device connectors

.LINK
    https://www.cisecurity.org/benchmark/microsoft_365

.COMPONENT
    Microsoft Graph Policy Entra Intune
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Scope of CIS controls to evaluate")]
    [ValidateSet('All', 'Entra', 'Intune')]
    [string]$Scope = 'All',

    [Parameter(HelpMessage = "Attempt to remediate non-compliant automatable controls")]
    [switch]$Remediate,

    [Parameter(HelpMessage = "Show what would be remediated without making changes")]
    [switch]$WhatIf,

    [Parameter(HelpMessage = "Skip confirmation prompts when remediating")]
    [switch]$Force,

    [Parameter(HelpMessage = "Export results: CSV, JSON, or None")]
    [ValidateSet('CSV', 'JSON', 'None')]
    [string]$ExportFormat = 'CSV'
)

$ErrorActionPreference = 'Stop'

$GraphBase = 'https://graph.microsoft.com/v1.0'

# -----------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------

function Invoke-GraphGet {
    param([string]$Path, [switch]$Count)
    $uri = "$GraphBase$Path"
    $headers = @{ ConsistencyLevel = 'eventual' }
    if ($Count) { $uri += '?$count=true' }
    return Invoke-MgGraphRequest -Method GET -Uri $uri -Headers $headers
}

function Invoke-GraphPatch {
    param([string]$Path, [hashtable]$Body)
    $uri = "$GraphBase$Path"
    $json = $Body | ConvertTo-Json -Depth 10 -Compress
    Invoke-MgGraphRequest -Method PATCH -Uri $uri -Body $json -ContentType 'application/json' | Out-Null
}

$results = [System.Collections.Generic.List[PSCustomObject]]::new()

function Add-Result {
    param(
        [string]$CisId,
        [string]$Category,
        [string]$Title,
        [ValidateSet('PASS', 'FAIL', 'ERROR', 'INFO')]
        [string]$Status,
        [string]$CurrentValue,
        [string]$Recommendation,
        [bool]$Remediable = $false,
        [string]$Detail = ''
    )
    $results.Add([PSCustomObject]@{
        CisId          = $CisId
        Category       = $Category
        Title          = $Title
        Status         = $Status
        CurrentValue   = $CurrentValue
        Recommendation = $Recommendation
        Remediable     = $Remediable
        Detail         = $Detail
        Timestamp      = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    })
}

# -----------------------------------------------------------------
# Entra ID checks
# -----------------------------------------------------------------

function Invoke-EntraChecks {
    Write-Host "`n🔍 Running Entra ID checks..." -ForegroundColor Cyan

    # ---- CIS-E-1.2.1 : Security Defaults -------------------------
    try {
        $sd = Invoke-GraphGet -Path '/policies/identitySecurityDefaultsEnforcementPolicy'
        $caCount = (Invoke-GraphGet -Path '/identity/conditionalAccess/policies').value.Count

        if ($caCount -gt 0 -and -not $sd.isEnabled) {
            Add-Result -CisId 'CIS-E-1.2.1' -Category 'Entra' `
                -Title 'Security Defaults disabled when Conditional Access is in use' `
                -Status 'PASS' -CurrentValue 'Disabled (CA policies active)' `
                -Recommendation 'Correct — Security Defaults and Conditional Access are mutually exclusive.'
        }
        elseif ($caCount -eq 0 -and $sd.isEnabled) {
            Add-Result -CisId 'CIS-E-1.2.1' -Category 'Entra' `
                -Title 'Security Defaults enabled (no Conditional Access configured)' `
                -Status 'PASS' -CurrentValue 'Enabled (no CA policies)' `
                -Recommendation 'Consider replacing Security Defaults with explicit Conditional Access policies.'
        }
        elseif ($caCount -eq 0 -and -not $sd.isEnabled) {
            Add-Result -CisId 'CIS-E-1.2.1' -Category 'Entra' `
                -Title 'Security Defaults disabled with no Conditional Access policies' `
                -Status 'FAIL' -CurrentValue 'Disabled (no CA policies)' `
                -Recommendation 'Enable Security Defaults or configure Conditional Access policies to enforce MFA.' `
                -Remediable $false `
                -Detail 'Enable at: Entra admin center > Properties > Manage Security Defaults'
        }
        else {
            Add-Result -CisId 'CIS-E-1.2.1' -Category 'Entra' `
                -Title 'Security Defaults enabled alongside Conditional Access policies' `
                -Status 'FAIL' -CurrentValue 'Enabled (CA policies also active)' `
                -Recommendation 'Disable Security Defaults — they conflict with Conditional Access policies.' `
                -Remediable $false `
                -Detail 'Disable at: Entra admin center > Properties > Manage Security Defaults'
        }
    }
    catch {
        Add-Result -CisId 'CIS-E-1.2.1' -Category 'Entra' -Title 'Security Defaults' `
            -Status 'ERROR' -CurrentValue 'N/A' -Recommendation 'Check Policy.Read.All permission.' `
            -Detail $_.Exception.Message
    }

    # ---- CIS-E-1.1.1 : Block Legacy Authentication ---------------
    try {
        $caPolicies = (Invoke-GraphGet -Path '/identity/conditionalAccess/policies').value

        $legacyBlockPolicy = $caPolicies | Where-Object {
            $_.state -eq 'enabled' -and
            $_.conditions.clientAppTypes -contains 'exchangeActiveSync' -and
            $_.conditions.clientAppTypes -contains 'other' -and
            $_.grantControls.builtInControls -contains 'block'
        }

        if ($legacyBlockPolicy) {
            Add-Result -CisId 'CIS-E-1.1.1' -Category 'Entra' `
                -Title 'Legacy Authentication blocked via Conditional Access' `
                -Status 'PASS' -CurrentValue "Policy: '$($legacyBlockPolicy[0].displayName)'" `
                -Recommendation 'Compliant — legacy authentication protocols are blocked.'
        }
        else {
            Add-Result -CisId 'CIS-E-1.1.1' -Category 'Entra' `
                -Title 'No Conditional Access policy blocks legacy authentication' `
                -Status 'FAIL' -CurrentValue 'No blocking CA policy found' `
                -Recommendation 'Create a CA policy targeting all users, conditions: client apps = Exchange ActiveSync + Other, grant = Block.' `
                -Remediable $false `
                -Detail 'Legacy auth (Basic auth, SMTP auth) bypasses MFA and is a common attack vector.'
        }
    }
    catch {
        Add-Result -CisId 'CIS-E-1.1.1' -Category 'Entra' -Title 'Block Legacy Authentication' `
            -Status 'ERROR' -CurrentValue 'N/A' -Recommendation 'Check Policy.Read.All permission.' `
            -Detail $_.Exception.Message
    }

    # ---- CIS-E-1.1.3 : Global Admin Count (2-4) ------------------
    try {
        $globalAdminRoleId = '62e90394-69f5-4237-9190-012177145e10'
        $roles = (Invoke-GraphGet -Path "/directoryRoles?`$filter=roleTemplateId eq '$globalAdminRoleId'").value

        if (-not $roles -or $roles.Count -eq 0) {
            Add-Result -CisId 'CIS-E-1.1.3' -Category 'Entra' `
                -Title 'Global Administrator role not activated' `
                -Status 'ERROR' -CurrentValue 'Role not found' `
                -Recommendation 'Activate the Global Administrator directory role.' `
                -Detail 'Role may not yet be activated in the tenant.'
        }
        else {
            $roleId = $roles[0].id
            $members = (Invoke-GraphGet -Path "/directoryRoles/$roleId/members").value
            $count = $members.Count

            if ($count -ge 2 -and $count -le 4) {
                Add-Result -CisId 'CIS-E-1.1.3' -Category 'Entra' `
                    -Title 'Between 2 and 4 Global Administrators designated' `
                    -Status 'PASS' -CurrentValue "$count Global Admin(s)" `
                    -Recommendation 'Compliant — maintain between 2 and 4 Global Admins.'
            }
            elseif ($count -lt 2) {
                Add-Result -CisId 'CIS-E-1.1.3' -Category 'Entra' `
                    -Title 'Too few Global Administrators (fewer than 2)' `
                    -Status 'FAIL' -CurrentValue "$count Global Admin(s)" `
                    -Recommendation 'Add at least one more Global Administrator for redundancy.' `
                    -Remediable $false
            }
            else {
                Add-Result -CisId 'CIS-E-1.1.3' -Category 'Entra' `
                    -Title 'Too many Global Administrators (more than 4)' `
                    -Status 'FAIL' -CurrentValue "$count Global Admin(s)" `
                    -Recommendation 'Reduce to 2–4 Global Admins; use least-privilege roles for other tasks.' `
                    -Remediable $false
            }
        }
    }
    catch {
        Add-Result -CisId 'CIS-E-1.1.3' -Category 'Entra' -Title 'Global Admin Count' `
            -Status 'ERROR' -CurrentValue 'N/A' -Recommendation 'Check Directory.Read.All permission.' `
            -Detail $_.Exception.Message
    }

    # ---- Authorization Policy (1.3.x controls) -------------------
    $authPolicy = $null
    try {
        $authPolicy = Invoke-GraphGet -Path '/policies/authorizationPolicy'
    }
    catch {
        foreach ($id in @('CIS-E-1.3.1', 'CIS-E-1.3.2', 'CIS-E-1.3.3', 'CIS-E-1.3.4')) {
            Add-Result -CisId $id -Category 'Entra' -Title 'Authorization Policy' `
                -Status 'ERROR' -CurrentValue 'N/A' `
                -Recommendation 'Check Policy.Read.All permission.' `
                -Detail $_.Exception.Message
        }
    }

    if ($authPolicy) {

        # ---- CIS-E-1.3.1 : Restrict tenant creation --------------
        $allowTenants = $authPolicy.defaultUserRolePermissions.allowedToCreateTenants
        if ($allowTenants -eq $false) {
            Add-Result -CisId 'CIS-E-1.3.1' -Category 'Entra' `
                -Title 'Non-admin users restricted from creating tenants' `
                -Status 'PASS' -CurrentValue 'Restricted (false)' `
                -Recommendation 'Compliant.'
        }
        else {
            Add-Result -CisId 'CIS-E-1.3.1' -Category 'Entra' `
                -Title 'Non-admin users can create new tenants' `
                -Status 'FAIL' -CurrentValue 'Allowed (true)' `
                -Recommendation 'Set allowedToCreateTenants to false in the Authorization Policy.' `
                -Remediable $true
        }

        # ---- CIS-E-1.3.2 : Restrict app registrations ------------
        $allowApps = $authPolicy.defaultUserRolePermissions.allowedToCreateApps
        if ($allowApps -eq $false) {
            Add-Result -CisId 'CIS-E-1.3.2' -Category 'Entra' `
                -Title 'Non-admin users restricted from registering applications' `
                -Status 'PASS' -CurrentValue 'Restricted (false)' `
                -Recommendation 'Compliant.'
        }
        else {
            Add-Result -CisId 'CIS-E-1.3.2' -Category 'Entra' `
                -Title 'Non-admin users can register applications' `
                -Status 'FAIL' -CurrentValue 'Allowed (true)' `
                -Recommendation 'Set allowedToCreateApps to false in the Authorization Policy.' `
                -Remediable $true
        }

        # ---- CIS-E-1.3.3 : User consent for third-party apps ----
        $grantPolicies  = $authPolicy.permissionGrantPoliciesAssigned
        $hasLegacyGrant = $grantPolicies -contains 'ManagePermissionGrantsForSelf.microsoft-user-default-legacy'

        if (-not $hasLegacyGrant) {
            $currentConsent = if ($grantPolicies.Count -eq 0) { 'None (disabled)' } else { ($grantPolicies -join ', ') }
            Add-Result -CisId 'CIS-E-1.3.3' -Category 'Entra' `
                -Title 'User consent for unverified third-party apps is restricted' `
                -Status 'PASS' -CurrentValue $currentConsent `
                -Recommendation 'Compliant — unrestricted user consent is not active.'
        }
        else {
            Add-Result -CisId 'CIS-E-1.3.3' -Category 'Entra' `
                -Title 'Users can consent to any third-party application' `
                -Status 'FAIL' -CurrentValue 'microsoft-user-default-legacy (unrestricted)' `
                -Recommendation 'Remove the legacy consent policy; restrict to verified publishers only or disable entirely.' `
                -Remediable $true `
                -Detail 'Unrestricted consent enables OAuth phishing attacks (illicit consent grant).'
        }

        # ---- CIS-E-1.3.4 : Guest user access restrictions -------
        # GUIDs: same-as-member = 10dae51f..., limited = bf6f7c50..., restricted = 2af84b1e...
        $guestRoleId = $authPolicy.guestUserRoleId
        $guestRoleMap = @{
            '10dae51f-b6af-4016-8d66-8c2a99b929b3' = 'Same access as members (most permissive)'
            'bf6f7c50-c52e-4f52-91fb-5cfea5baf8d8' = 'Limited access'
            '2af84b1e-32c8-42b7-82bc-daa82404023b' = 'Restricted access (most restrictive)'
        }
        $guestRoleLabel = if ($guestRoleMap[$guestRoleId]) { $guestRoleMap[$guestRoleId] } else { $guestRoleId }

        if ($guestRoleId -eq '10dae51f-b6af-4016-8d66-8c2a99b929b3') {
            Add-Result -CisId 'CIS-E-1.3.4' -Category 'Entra' `
                -Title 'Guest users have same access as members' `
                -Status 'FAIL' -CurrentValue $guestRoleLabel `
                -Recommendation 'Restrict guest access to limited or restricted level.' `
                -Remediable $true
        }
        else {
            Add-Result -CisId 'CIS-E-1.3.4' -Category 'Entra' `
                -Title 'Guest user access is restricted' `
                -Status 'PASS' -CurrentValue $guestRoleLabel `
                -Recommendation 'Compliant.'
        }
    }

    # ---- CIS-E-1.4.1 : Admin Consent Workflow --------------------
    try {
        $acrp = Invoke-GraphGet -Path '/policies/adminConsentRequestPolicy'

        if ($acrp.isEnabled -eq $true) {
            Add-Result -CisId 'CIS-E-1.4.1' -Category 'Entra' `
                -Title 'Admin consent workflow is enabled' `
                -Status 'PASS' -CurrentValue 'Enabled' `
                -Recommendation 'Compliant — users can request admin consent instead of consenting directly.'
        }
        else {
            Add-Result -CisId 'CIS-E-1.4.1' -Category 'Entra' `
                -Title 'Admin consent workflow is disabled' `
                -Status 'FAIL' -CurrentValue 'Disabled' `
                -Recommendation 'Enable the admin consent workflow so users can request app access approval.' `
                -Remediable $true `
                -Detail 'Without this, users either have unrestricted consent or no path to request access.'
        }
    }
    catch {
        Add-Result -CisId 'CIS-E-1.4.1' -Category 'Entra' -Title 'Admin Consent Workflow' `
            -Status 'ERROR' -CurrentValue 'N/A' `
            -Recommendation 'Check Policy.Read.All permission.' `
            -Detail $_.Exception.Message
    }

    Write-Host "   ✅ Entra checks complete" -ForegroundColor Green
}

# -----------------------------------------------------------------
# Intune checks
# -----------------------------------------------------------------

function Invoke-IntuneChecks {
    Write-Host "`n🔍 Running Intune checks..." -ForegroundColor Cyan

    # ---- CIS-I-5.1.1 : MDM Authority ----------------------------
    try {
        $dm = Invoke-GraphGet -Path '/deviceManagement'
        $mdmAuth = $dm.mdmAuthority

        if ($mdmAuth -in @('intune', 'office365')) {
            Add-Result -CisId 'CIS-I-5.1.1' -Category 'Intune' `
                -Title 'MDM Authority is configured' `
                -Status 'PASS' -CurrentValue $mdmAuth `
                -Recommendation 'Compliant — devices can be enrolled and managed.'
        }
        else {
            Add-Result -CisId 'CIS-I-5.1.1' -Category 'Intune' `
                -Title 'MDM Authority is not configured' `
                -Status 'FAIL' -CurrentValue ($mdmAuth ?? 'notConfigured') `
                -Recommendation 'Set MDM Authority to Intune in the Intune admin center.' `
                -Remediable $false
        }
    }
    catch {
        Add-Result -CisId 'CIS-I-5.1.1' -Category 'Intune' -Title 'MDM Authority' `
            -Status 'ERROR' -CurrentValue 'N/A' `
            -Recommendation 'Check DeviceManagementServiceConfig.Read.All permission.' `
            -Detail $_.Exception.Message
    }

    # ---- CIS-I-5.1.2 : Compliance Policies Exist ----------------
    try {
        $compliancePolicies = (Invoke-GraphGet -Path '/deviceManagement/deviceCompliancePolicies').value
        $count = @($compliancePolicies).Count

        if ($count -gt 0) {
            Add-Result -CisId 'CIS-I-5.1.2' -Category 'Intune' `
                -Title 'Device compliance policies are configured' `
                -Status 'PASS' -CurrentValue "$count compliance policy/policies" `
                -Recommendation 'Compliant — ensure policies cover all managed platforms.'
        }
        else {
            Add-Result -CisId 'CIS-I-5.1.2' -Category 'Intune' `
                -Title 'No device compliance policies configured' `
                -Status 'FAIL' -CurrentValue 'None' `
                -Recommendation 'Create compliance policies for each managed platform (Windows, iOS, Android, macOS).' `
                -Remediable $false `
                -Detail 'Without compliance policies, all devices are treated as compliant by default.'
        }
    }
    catch {
        Add-Result -CisId 'CIS-I-5.1.2' -Category 'Intune' -Title 'Device Compliance Policies' `
            -Status 'ERROR' -CurrentValue 'N/A' `
            -Recommendation 'Check DeviceManagementConfiguration.Read.All permission.' `
            -Detail $_.Exception.Message
    }

    # ---- CIS-I-5.2.1 : Defender for Endpoint Integration --------
    try {
        $mtdConnectors = (Invoke-GraphGet -Path '/deviceManagement/mobileThreatDefenseConnectors').value
        $mdeConnector = $mtdConnectors | Where-Object {
            $_.partnerType -eq 'microsoftDefenderForEndpoint' -or
            $_.partnerType -eq 'windowsDefenderATP'
        }

        if ($mdeConnector) {
            $enabled = $mdeConnector[0].windowsEnabled -or $mdeConnector[0].androidEnabled -or $mdeConnector[0].iosEnabled
            if ($enabled) {
                Add-Result -CisId 'CIS-I-5.2.1' -Category 'Intune' `
                    -Title 'Microsoft Defender for Endpoint integration is active' `
                    -Status 'PASS' -CurrentValue "Connector: $($mdeConnector[0].partnerType)" `
                    -Recommendation 'Compliant — device risk signals flow from MDE to Intune.'
            }
            else {
                Add-Result -CisId 'CIS-I-5.2.1' -Category 'Intune' `
                    -Title 'MDE connector exists but no platform is enabled' `
                    -Status 'FAIL' -CurrentValue 'Connector present but disabled' `
                    -Recommendation 'Enable the MDE connector for Windows, iOS, and/or Android in Intune.' `
                    -Remediable $false
            }
        }
        else {
            Add-Result -CisId 'CIS-I-5.2.1' -Category 'Intune' `
                -Title 'Microsoft Defender for Endpoint is not integrated with Intune' `
                -Status 'FAIL' -CurrentValue 'No MDE connector' `
                -Recommendation 'Configure the MDE connector in Intune: Endpoint security > Microsoft Defender for Endpoint.' `
                -Remediable $false `
                -Detail 'Requires Microsoft Defender for Endpoint Plan 1 or Plan 2 license.'
        }
    }
    catch {
        Add-Result -CisId 'CIS-I-5.2.1' -Category 'Intune' `
            -Title 'Defender for Endpoint Integration' `
            -Status 'ERROR' -CurrentValue 'N/A' `
            -Recommendation 'Check DeviceManagementManagedDevices.Read.All permission.' `
            -Detail $_.Exception.Message
    }

    # ---- CIS-I-5.3.1 : Require Compliant Device in CA -----------
    try {
        $caPolicies = (Invoke-GraphGet -Path '/identity/conditionalAccess/policies').value
        $complianceCa = $caPolicies | Where-Object {
            $_.state -eq 'enabled' -and
            $_.grantControls.builtInControls -contains 'compliantDevice'
        }

        if ($complianceCa) {
            Add-Result -CisId 'CIS-I-5.3.1' -Category 'Intune' `
                -Title 'Conditional Access requires compliant device' `
                -Status 'PASS' -CurrentValue "Policy: '$($complianceCa[0].displayName)'" `
                -Recommendation 'Compliant — device compliance is enforced via Conditional Access.'
        }
        else {
            Add-Result -CisId 'CIS-I-5.3.1' -Category 'Intune' `
                -Title 'No Conditional Access policy requires a compliant device' `
                -Status 'FAIL' -CurrentValue 'No matching CA policy' `
                -Recommendation 'Create a CA policy with grant control: Require device to be marked as compliant.' `
                -Remediable $false `
                -Detail 'Without this, non-compliant or unmanaged devices can access corporate resources.'
        }
    }
    catch {
        Add-Result -CisId 'CIS-I-5.3.1' -Category 'Intune' `
            -Title 'Require Compliant Device (CA)' `
            -Status 'ERROR' -CurrentValue 'N/A' `
            -Recommendation 'Check Policy.Read.All permission.' `
            -Detail $_.Exception.Message
    }

    Write-Host "   ✅ Intune checks complete" -ForegroundColor Green
}

# -----------------------------------------------------------------
# Remediation
# -----------------------------------------------------------------

function Invoke-Remediation {
    param([System.Collections.Generic.List[PSCustomObject]]$Results)

    $remediable = @($Results | Where-Object { $_.Status -eq 'FAIL' -and $_.Remediable -eq $true })

    if ($remediable.Count -eq 0) {
        Write-Host "`nℹ️  No automatically remediable findings." -ForegroundColor Yellow
        return
    }

    Write-Host "`n🔧 Remediable findings ($($remediable.Count)):" -ForegroundColor Cyan
    foreach ($r in $remediable) {
        Write-Host "   • [$($r.CisId)] $($r.Title)" -ForegroundColor Yellow
    }

    if ($WhatIf) {
        Write-Host "`n🔍 WhatIf mode — no changes will be made." -ForegroundColor Cyan
        return
    }

    if (-not $Force) {
        Write-Host "`n⚠️  About to remediate $($remediable.Count) setting(s)." -ForegroundColor Yellow
        $confirmation = Read-Host "Type 'YES' to confirm"
        if ($confirmation -ne 'YES') {
            Write-Host 'Remediation cancelled by user.' -ForegroundColor Yellow
            return
        }
    }

    # Build combined authorization policy patch (merge all authPolicy changes)
    $authPatch = @{}
    $authPolicyUserPermsPatch = @{}

    foreach ($r in $remediable) {
        try {
            switch ($r.CisId) {

                'CIS-E-1.3.1' {
                    $authPolicyUserPermsPatch['allowedToCreateTenants'] = $false
                }

                'CIS-E-1.3.2' {
                    $authPolicyUserPermsPatch['allowedToCreateApps'] = $false
                }

                'CIS-E-1.3.3' {
                    # Remove legacy unrestricted consent; keep restricted-to-verified-publishers if present
                    $current = (Invoke-GraphGet -Path '/policies/authorizationPolicy').permissionGrantPoliciesAssigned
                    $updated = @($current | Where-Object { $_ -ne 'ManagePermissionGrantsForSelf.microsoft-user-default-legacy' })
                    $authPatch['permissionGrantPoliciesAssigned'] = $updated
                }

                'CIS-E-1.3.4' {
                    # Set to limited guest access (bf6f7c50...) — less disruptive than fully restricted
                    $authPatch['guestUserRoleId'] = 'bf6f7c50-c52e-4f52-91fb-5cfea5baf8d8'
                }

                'CIS-E-1.4.1' {
                    Invoke-GraphPatch -Path '/policies/adminConsentRequestPolicy' -Body @{
                        isEnabled          = $true
                        version            = 1
                        notifyReviewers    = $true
                        remindersEnabled   = $true
                        requestDurationInDays = 30
                        reviewers          = @()
                    }
                    Write-Host "   ✅ Remediated [$($r.CisId)]: Admin consent workflow enabled." -ForegroundColor Green
                    $r.Status = 'PASS'
                    $r.CurrentValue = 'Enabled (remediated)'
                }
            }
        }
        catch {
            Write-Host "   ❌ Failed to remediate [$($r.CisId)]: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    # Apply authorization policy patches as a single PATCH
    if ($authPolicyUserPermsPatch.Count -gt 0) {
        $authPatch['defaultUserRolePermissions'] = $authPolicyUserPermsPatch
    }

    if ($authPatch.Count -gt 0) {
        try {
            Invoke-GraphPatch -Path '/policies/authorizationPolicy' -Body $authPatch
            foreach ($id in ($remediable | Where-Object { $_.CisId -in @('CIS-E-1.3.1', 'CIS-E-1.3.2', 'CIS-E-1.3.3', 'CIS-E-1.3.4') } | Select-Object -ExpandProperty CisId)) {
                $r = $results | Where-Object { $_.CisId -eq $id }
                if ($r) {
                    $r.Status = 'PASS'
                    $r.CurrentValue = 'Remediated'
                    Write-Host "   ✅ Remediated [$id]: Authorization policy updated." -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Host "   ❌ Failed to patch Authorization Policy: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# -----------------------------------------------------------------
# Main execution
# -----------------------------------------------------------------

try {
    Write-Host '===== CIS Microsoft 365 Benchmark Check =====' -ForegroundColor Blue
    Write-Host "Scope:     $Scope" -ForegroundColor Cyan
    Write-Host "Remediate: $Remediate" -ForegroundColor Cyan
    Write-Host "WhatIf:    $WhatIf" -ForegroundColor Cyan

    if ($Scope -in @('All', 'Entra')) { Invoke-EntraChecks }
    if ($Scope -in @('All', 'Intune')) { Invoke-IntuneChecks }

    if ($Remediate) {
        Invoke-Remediation -Results $results
    }

    # ----- Display results table ----------------------------------
    $passCount  = ($results | Where-Object { $_.Status -eq 'PASS' }).Count
    $failCount  = ($results | Where-Object { $_.Status -eq 'FAIL' }).Count
    $errorCount = ($results | Where-Object { $_.Status -eq 'ERROR' }).Count

    Write-Host "`n📊 Results:" -ForegroundColor Blue

    foreach ($r in $results) {
        $icon = switch ($r.Status) {
            'PASS'  { '✅' }
            'FAIL'  { '❌' }
            'ERROR' { '⚠️ ' }
            default { 'ℹ️ ' }
        }
        $color = switch ($r.Status) {
            'PASS'  { 'Green' }
            'FAIL'  { 'Red' }
            'ERROR' { 'Yellow' }
            default { 'White' }
        }
        Write-Host "$icon [$($r.CisId)] $($r.Title)" -ForegroundColor $color
        Write-Host "     Current: $($r.CurrentValue)" -ForegroundColor Gray
        if ($r.Status -eq 'FAIL') {
            Write-Host "     Fix:     $($r.Recommendation)" -ForegroundColor Yellow
            if ($r.Remediable -and -not $Remediate) {
                Write-Host "     💡 Auto-remediable with -Remediate" -ForegroundColor Cyan
            }
        }
    }

    Write-Host "`n📊 Summary:" -ForegroundColor Blue
    Write-Host "   ✅ PASS:  $passCount" -ForegroundColor Green
    Write-Host "   ❌ FAIL:  $failCount" -ForegroundColor Red
    if ($errorCount -gt 0) {
        Write-Host "   ⚠️  ERROR: $errorCount" -ForegroundColor Yellow
    }
    $remediableCount = ($results | Where-Object { $_.Status -eq 'FAIL' -and $_.Remediable }).Count
    if ($remediableCount -gt 0 -and -not $Remediate) {
        Write-Host "`n💡 $remediableCount finding(s) can be auto-remediated. Re-run with -Remediate to apply fixes." -ForegroundColor Cyan
    }

    # ----- Export -------------------------------------------------
    if ($ExportFormat -ne 'None') {
        $timestamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
        $exportFile = "cis-benchmark-results-$timestamp.$($ExportFormat.ToLower())"

        if ($ExportFormat -eq 'CSV') {
            $results | Export-Csv -Path $exportFile -NoTypeInformation -Encoding UTF8
        }
        else {
            $results | ConvertTo-Json -Depth 5 | Out-File -FilePath $exportFile -Encoding UTF8
        }

        Write-Host "`n📁 Results exported to: $exportFile" -ForegroundColor Cyan
    }

    Write-Host "`n=============================================" -ForegroundColor Blue
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
