<#
.SYNOPSIS
    List and filter Entra ID groups via the Microsoft Graph API.

.DESCRIPTION
    This script retrieves Entra ID (Azure AD) groups using the Microsoft Graph API.
    Supports filtering by group type, searching by name, and exporting results.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: GET /groups

.PARAMETER Filter
    OData filter expression to narrow results.
    Example: "groupTypes/any(c:c eq 'Unified')" for Microsoft 365 groups.

.PARAMETER Search
    Search string applied to displayName and description.

.PARAMETER GroupType
    Filter groups by type. Valid values: All, Security, Microsoft365, MailEnabled.

.PARAMETER Top
    Maximum number of groups to return. Defaults to 100.

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, List, JSON, CSV.

.EXAMPLE
    .\msgraph-get-entra-groups.ps1
    Lists all groups.

.EXAMPLE
    .\msgraph-get-entra-groups.ps1 -GroupType Security -OutputFormat Table
    Lists all security groups in table format.

.EXAMPLE
    .\msgraph-get-entra-groups.ps1 -Search "Admins" -OutputFormat CSV
    Exports all groups matching "Admins" to a CSV file in the current directory.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: Group.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/group-list

.COMPONENT
    Microsoft Graph, Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "OData filter expression")]
    [string]$Filter,

    [Parameter(Mandatory = $false, HelpMessage = "Search string for displayName and description")]
    [string]$Search,

    [Parameter(Mandatory = $false, HelpMessage = "Filter groups by type")]
    [ValidateSet('All', 'Security', 'Microsoft365', 'MailEnabled')]
    [string]$GroupType = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of results to return")]
    [ValidateRange(1, 999)]
    [int]$Top = 100,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'List', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

try {
    Write-Host "📋 Entra ID Group Listing" -ForegroundColor Blue
    Write-Host "=========================" -ForegroundColor Blue

    $select = "id,displayName,description,groupTypes,mailEnabled,securityEnabled,membershipRule,createdDateTime"
    $queryString = @("`$top=$Top", "`$select=$select")
    $headers = @{}

    # Apply type filter
    $typeFilter = switch ($GroupType) {
        'Security'    { "securityEnabled eq true and mailEnabled eq false and NOT groupTypes/any(c:c eq 'Unified')" }
        'Microsoft365' { "groupTypes/any(c:c eq 'Unified')" }
        'MailEnabled' { "mailEnabled eq true" }
        default       { $null }
    }

    $filterParts = @()
    if ($typeFilter) { $filterParts += $typeFilter }
    if ($Filter)     { $filterParts += $Filter }

    if ($filterParts.Count -gt 0) {
        $combinedFilter = $filterParts -join " and "
        Write-Host "🔍 Applying filter: $combinedFilter" -ForegroundColor Cyan
        $queryString += "`$filter=$([Uri]::EscapeDataString($combinedFilter))"
    }

    if ($Search) {
        Write-Host "🔍 Applying search: $Search" -ForegroundColor Cyan
        $queryString += "`$search=`"displayName:$Search`""
        $headers['ConsistencyLevel'] = "eventual"
        $queryString += "`$count=true"
    }

    $uri = "https://graph.microsoft.com/v1.0/groups?" + ($queryString -join "&")

    # Retrieve groups
    Write-Host "🔄 Retrieving groups from Microsoft Graph..." -ForegroundColor Cyan

    $requestParams = @{ Uri = $uri; Method = "GET" }
    if ($headers.Count -gt 0) { $requestParams['Headers'] = $headers }

    $response = Invoke-MgGraphRequest @requestParams
    $groups = [System.Collections.Generic.List[PSObject]]::new()
    $groups.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink -and $groups.Count -lt $Top) {
        Write-Host "   ↳ Fetching next page..." -ForegroundColor Gray
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $groups.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    if ($groups.Count -eq 0) {
        Write-Host "ℹ️  No groups found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "✅ Retrieved $($groups.Count) group(s)" -ForegroundColor Green

    # Enrich with resolved group type label
    $groups = $groups | ForEach-Object {
        $type = if ($_.groupTypes -contains 'Unified') { 'Microsoft 365' }
                elseif ($_.securityEnabled -and -not $_.mailEnabled) { 'Security' }
                elseif ($_.mailEnabled -and $_.securityEnabled) { 'Mail-enabled Security' }
                else { 'Distribution' }
        $_ | Add-Member -NotePropertyName 'ResolvedType' -NotePropertyValue $type -PassThru
    }

    switch ($OutputFormat) {
        'Table' {
            $groups | Select-Object displayName, ResolvedType,
                @{N='Dynamic'; E={ ($_.membershipRule) ? 'Yes' : 'No' }},
                @{N='Created'; E={ $_.createdDateTime }},
                description |
                Format-Table -AutoSize
        }
        'List' {
            foreach ($group in $groups) {
                Write-Host "`n👥 $($group.displayName)" -ForegroundColor Yellow
                Write-Host "   Object ID:   $($group.id)" -ForegroundColor White
                Write-Host "   Type:        $($group.ResolvedType)" -ForegroundColor White
                Write-Host "   Dynamic:     $(if ($group.membershipRule) { 'Yes' } else { 'No' })" -ForegroundColor White
                Write-Host "   Created:     $($group.createdDateTime)" -ForegroundColor White
                if ($group.description) {
                    Write-Host "   Description: $($group.description)" -ForegroundColor White
                }
            }
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "entra-groups-$timestamp.json"
            $groups | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported $($groups.Count) groups to: $filePath" -ForegroundColor Green
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "entra-groups-$timestamp.csv"
            $groups | Select-Object id, displayName, ResolvedType, description,
                @{N='IsDynamic'; E={ [bool]$_.membershipRule }}, createdDateTime |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported $($groups.Count) groups to: $filePath" -ForegroundColor Green
        }
    }

    Write-Host "`n📊 Summary: $($groups.Count) group(s) returned" -ForegroundColor Blue
}
catch {
    Write-Host "❌ Failed to retrieve Entra ID groups: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
