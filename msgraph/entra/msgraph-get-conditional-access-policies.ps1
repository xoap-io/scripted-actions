<#
.SYNOPSIS
    List Entra ID Conditional Access policies via the Microsoft Graph API.

.DESCRIPTION
    This script retrieves Conditional Access policies from Entra ID using the Microsoft
    Graph API. Supports filtering by state and exporting results for auditing purposes.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: GET /identity/conditionalAccess/policies

.PARAMETER State
    Filter policies by their state. Valid values: All, Enabled, Disabled, EnabledForReportingButNotEnforced.

.PARAMETER Search
    Filter policies by display name (case-insensitive substring match).

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, List, JSON, CSV.

.EXAMPLE
    .\msgraph-get-conditional-access-policies.ps1
    Lists all Conditional Access policies.

.EXAMPLE
    .\msgraph-get-conditional-access-policies.ps1 -State Enabled -OutputFormat Table
    Lists all enabled Conditional Access policies in table format.

.EXAMPLE
    .\msgraph-get-conditional-access-policies.ps1 -OutputFormat JSON
    Exports all policies to a JSON file in the current directory for auditing.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: Policy.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/conditionalaccessroot-list-policies

.COMPONENT
    Microsoft Graph, Entra ID, Conditional Access
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Filter policies by state")]
    [ValidateSet('All', 'enabled', 'disabled', 'enabledForReportingButNotEnforced')]
    [string]$State = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by display name substring")]
    [string]$Search,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'List', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    Write-Host "🔒 Conditional Access Policy Listing" -ForegroundColor Blue
    Write-Host "======================================" -ForegroundColor Blue

    $uri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"

    if ($State -ne 'All') {
        $encodedFilter = [Uri]::EscapeDataString("state eq '$State'")
        $uri += "?`$filter=$encodedFilter"
        Write-Host "🔍 Filtering by state: $State" -ForegroundColor Cyan
    }

    Write-Host "🔄 Retrieving Conditional Access policies..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET

    $policies = [System.Collections.Generic.List[PSObject]]::new()
    $policies.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink) {
        Write-Host "   ↳ Fetching next page..." -ForegroundColor Gray
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $policies.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    # Client-side name filter
    if ($Search) {
        Write-Host "🔍 Filtering by name: $Search" -ForegroundColor Cyan
        $policies = $policies | Where-Object { $_.displayName -match [regex]::Escape($Search) }
    }

    if ($policies.Count -eq 0) {
        Write-Host "ℹ️  No Conditional Access policies found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "✅ Retrieved $($policies.Count) policy/policies" -ForegroundColor Green

    switch ($OutputFormat) {
        'Table' {
            $policies | Select-Object displayName,
                @{N='State'; E={ $_.state }},
                @{N='Users'; E={
                    $inc = @($_.conditions.users.includeUsers) + @($_.conditions.users.includeGroups)
                    if ($inc -contains 'All') { 'All Users' } else { "$($inc.Count) included" }
                }},
                @{N='Grant Controls'; E={ $_.grantControls.builtInControls -join ', ' }},
                @{N='Created'; E={ $_.createdDateTime }} |
                Format-Table -AutoSize
        }
        'List' {
            foreach ($policy in $policies) {
                $stateColor = switch ($policy.state) {
                    'enabled'                           { 'Green' }
                    'disabled'                          { 'Red' }
                    'enabledForReportingButNotEnforced' { 'Yellow' }
                    default                             { 'White' }
                }
                Write-Host "`n🔒 $($policy.displayName)" -ForegroundColor Yellow
                Write-Host "   ID:       $($policy.id)" -ForegroundColor White
                Write-Host "   State:    $($policy.state)" -ForegroundColor $stateColor
                Write-Host "   Created:  $($policy.createdDateTime)" -ForegroundColor White
                Write-Host "   Modified: $($policy.modifiedDateTime)" -ForegroundColor White

                if ($policy.conditions.users.includeUsers -contains 'All') {
                    Write-Host "   Users:    All users" -ForegroundColor White
                } elseif ($policy.conditions.users.includeGroups.Count -gt 0) {
                    Write-Host "   Users:    $($policy.conditions.users.includeGroups.Count) group(s) included" -ForegroundColor White
                }

                if ($policy.grantControls.builtInControls) {
                    Write-Host "   Grant:    $($policy.grantControls.builtInControls -join ', ')" -ForegroundColor White
                }

                if ($policy.sessionControls) {
                    Write-Host "   Session:  Controls configured" -ForegroundColor White
                }
            }
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "conditional-access-policies-$timestamp.json"
            $policies | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported $($policies.Count) policies to: $filePath" -ForegroundColor Green
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "conditional-access-policies-$timestamp.csv"
            $policies | Select-Object id, displayName, state, createdDateTime, modifiedDateTime,
                @{N='GrantControls'; E={ $_.grantControls.builtInControls -join ',' }},
                @{N='IncludeUsers'; E={ $_.conditions.users.includeUsers -join ',' }},
                @{N='IncludeGroups'; E={ $_.conditions.users.includeGroups -join ',' }} |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported $($policies.Count) policies to: $filePath" -ForegroundColor Green
        }
    }

    Write-Host "`n📊 Summary: $($policies.Count) policy/policies returned" -ForegroundColor Blue
}
catch {
    Write-Host "❌ Failed to retrieve Conditional Access policies: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
