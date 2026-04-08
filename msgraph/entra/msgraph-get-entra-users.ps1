<#
.SYNOPSIS
    List and filter Entra ID users via the Microsoft Graph API.

.DESCRIPTION
    This script retrieves Entra ID (Azure AD) user accounts using the Microsoft Graph API.
    Supports filtering, selecting specific properties, and exporting results in multiple formats.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: GET /users

.PARAMETER Filter
    OData filter expression to narrow results.
    Example: "department eq 'Engineering'" or "accountEnabled eq false"

.PARAMETER Search
    Search string applied to displayName, mail, and userPrincipalName.

.PARAMETER Select
    Comma-separated list of user properties to retrieve.
    Defaults to common properties when not specified.

.PARAMETER Top
    Maximum number of users to return. Defaults to 100.

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, List, JSON, CSV.

.EXAMPLE
    .\msgraph-get-entra-users.ps1
    Lists all users with default properties.

.EXAMPLE
    .\msgraph-get-entra-users.ps1 -Filter "department eq 'IT'" -OutputFormat Table
    Lists all users in the IT department in table format.

.EXAMPLE
    .\msgraph-get-entra-users.ps1 -Filter "accountEnabled eq false" -OutputFormat CSV
    Exports all disabled accounts to a CSV file in the current directory.

.EXAMPLE
    .\msgraph-get-entra-users.ps1 -Search "Smith" -Top 50
    Returns up to 50 users matching the name "Smith".

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: User.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/user-list

.COMPONENT
    Microsoft Graph, Entra ID
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "OData filter expression")]
    [string]$Filter,

    [Parameter(Mandatory = $false, HelpMessage = "Search string for displayName, mail, userPrincipalName")]
    [string]$Search,

    [Parameter(Mandatory = $false, HelpMessage = "Comma-separated list of properties to retrieve")]
    [string]$Select = "id,displayName,userPrincipalName,mail,department,jobTitle,accountEnabled,createdDateTime",

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
    Write-Host "📋 Entra ID User Listing" -ForegroundColor Blue
    Write-Host "========================" -ForegroundColor Blue

    # Build query parameters
    $queryParams = @{
        Uri    = "https://graph.microsoft.com/v1.0/users"
        Method = "GET"
    }

    $queryString = @("`$top=$Top", "`$select=$Select")

    if ($Filter) {
        Write-Host "🔍 Applying filter: $Filter" -ForegroundColor Cyan
        $queryString += "`$filter=$([Uri]::EscapeDataString($Filter))"
    }

    if ($Search) {
        Write-Host "🔍 Applying search: $Search" -ForegroundColor Cyan
        $queryString += "`$search=`"$Search`""
        $queryParams['Headers'] = @{ ConsistencyLevel = "eventual" }
    }

    $queryParams['Uri'] += "?" + ($queryString -join "&")

    # Retrieve users from Graph API
    Write-Host "🔄 Retrieving users from Microsoft Graph..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest @queryParams

    $users = [System.Collections.Generic.List[PSObject]]::new()
    $users.AddRange([PSObject[]]$response.value)

    # Follow pagination if needed
    $nextLink = $response.'@odata.nextLink'
    while ($nextLink -and $users.Count -lt $Top) {
        Write-Host "   ↳ Fetching next page..." -ForegroundColor Gray
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $users.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    if ($users.Count -eq 0) {
        Write-Host "ℹ️  No users found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "✅ Retrieved $($users.Count) user(s)" -ForegroundColor Green

    # Output results
    switch ($OutputFormat) {
        'Table' {
            $users | Select-Object displayName, userPrincipalName, department, jobTitle,
                @{N='Enabled'; E={ $_.accountEnabled }},
                @{N='Created'; E={ $_.createdDateTime }} |
                Format-Table -AutoSize
        }
        'List' {
            foreach ($user in $users) {
                Write-Host "`n👤 $($user.displayName)" -ForegroundColor Yellow
                Write-Host "   UPN:         $($user.userPrincipalName)" -ForegroundColor White
                Write-Host "   Mail:        $($user.mail)" -ForegroundColor White
                Write-Host "   Department:  $($user.department)" -ForegroundColor White
                Write-Host "   Job Title:   $($user.jobTitle)" -ForegroundColor White
                Write-Host "   Enabled:     $($user.accountEnabled)" -ForegroundColor White
                Write-Host "   Created:     $($user.createdDateTime)" -ForegroundColor White
                Write-Host "   Object ID:   $($user.id)" -ForegroundColor Gray
            }
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "entra-users-$timestamp.json"
            $users | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported $($users.Count) users to: $filePath" -ForegroundColor Green
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "entra-users-$timestamp.csv"
            $users | Select-Object id, displayName, userPrincipalName, mail, department, jobTitle, accountEnabled, createdDateTime |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported $($users.Count) users to: $filePath" -ForegroundColor Green
        }
    }

    Write-Host "`n📊 Summary: $($users.Count) user(s) returned" -ForegroundColor Blue
}
catch {
    Write-Host "❌ Failed to retrieve Entra ID users: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
