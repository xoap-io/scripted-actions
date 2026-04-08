<#
.SYNOPSIS
    List Microsoft Intune managed applications via the Microsoft Graph API.

.DESCRIPTION
    This script retrieves mobile apps configured in Microsoft Intune using the Microsoft
    Graph API. Supports filtering by platform, app type, and publisher, with multiple
    output format options.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoint: GET /deviceAppManagement/mobileApps

.PARAMETER Platform
    Filter apps by target platform. Valid values: All, Windows, iOS, Android, macOS.

.PARAMETER AppType
    Filter by app type. Valid values: All, Store, LOB, WebApp, BuiltIn.

.PARAMETER Publisher
    Filter apps by publisher name (substring match).

.PARAMETER Top
    Maximum number of apps to return. Defaults to 100.

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, List, JSON, CSV.

.EXAMPLE
    .\msgraph-get-intune-apps.ps1
    Lists all managed apps.

.EXAMPLE
    .\msgraph-get-intune-apps.ps1 -Platform Windows -AppType Store
    Lists all Windows Store apps.

.EXAMPLE
    .\msgraph-get-intune-apps.ps1 -Publisher "Microsoft" -OutputFormat Table
    Lists all apps published by Microsoft in table format.

.EXAMPLE
    .\msgraph-get-intune-apps.ps1 -OutputFormat CSV
    Exports all apps to a CSV report in the current directory.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: DeviceManagementApps.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileapp-list

.COMPONENT
    Microsoft Graph, Microsoft Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Filter apps by platform")]
    [ValidateSet('All', 'Windows', 'iOS', 'Android', 'macOS')]
    [string]$Platform = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by app type")]
    [ValidateSet('All', 'Store', 'LOB', 'WebApp', 'BuiltIn')]
    [string]$AppType = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by publisher name (substring)")]
    [string]$Publisher,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum number of results to return")]
    [ValidateRange(1, 999)]
    [int]$Top = 100,

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'List', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

# Map platform parameter to odata.type filter patterns
$platformTypeMap = @{
    'Windows' = @('windowsStoreApp', 'win32LobApp', 'windowsMobileMSI', 'windowsWebApp', 'officeSuiteApp', 'windowsUniversalAppX')
    'iOS'     = @('iosStoreApp', 'iosLobApp', 'iosVppApp', 'managedIOSStoreApp', 'managedIOSLobApp')
    'Android' = @('androidStoreApp', 'androidLobApp', 'androidForWorkApp', 'managedAndroidStoreApp', 'managedAndroidLobApp')
    'macOS'   = @('macOSLobApp', 'macOSMicrosoftEdgeApp', 'macOSOfficeSuiteApp', 'macOsDmgApp')
}

$appTypePatterns = @{
    'Store'   = @('StoreApp', 'VppApp')
    'LOB'     = @('LobApp', 'mobileMSI')
    'WebApp'  = @('WebApp')
    'BuiltIn' = @('managedAndroid', 'managedIOS', 'officeSuiteApp')
}

try {
    Write-Host "📦 Intune App Listing" -ForegroundColor Blue
    Write-Host "=====================" -ForegroundColor Blue

    $select = "id,displayName,publisher,description,@odata.type,createdDateTime,lastModifiedDateTime,isAssigned"
    $uri = "https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps?`$top=$Top&`$select=$select"

    Write-Host "🔄 Retrieving apps from Microsoft Graph..." -ForegroundColor Cyan
    $response = Invoke-MgGraphRequest -Uri $uri -Method GET

    $apps = [System.Collections.Generic.List[PSObject]]::new()
    $apps.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink -and $apps.Count -lt $Top) {
        Write-Host "   ↳ Fetching next page..." -ForegroundColor Gray
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $apps.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    # Client-side filtering by platform
    if ($Platform -ne 'All' -and $platformTypeMap.ContainsKey($Platform)) {
        $patterns = $platformTypeMap[$Platform]
        Write-Host "🔍 Filtering by platform: $Platform" -ForegroundColor Cyan
        $apps = $apps | Where-Object {
            $odataType = $_.'@odata.type' -replace '#microsoft.graph.', ''
            $patterns | Where-Object { $odataType -like "*$_*" }
        }
    }

    # Client-side filtering by app type
    if ($AppType -ne 'All' -and $appTypePatterns.ContainsKey($AppType)) {
        $patterns = $appTypePatterns[$AppType]
        Write-Host "🔍 Filtering by app type: $AppType" -ForegroundColor Cyan
        $apps = $apps | Where-Object {
            $odataType = $_.'@odata.type' -replace '#microsoft.graph.', ''
            $patterns | Where-Object { $odataType -like "*$_*" }
        }
    }

    # Client-side filtering by publisher
    if ($Publisher) {
        Write-Host "🔍 Filtering by publisher: $Publisher" -ForegroundColor Cyan
        $apps = $apps | Where-Object { $_.publisher -match [regex]::Escape($Publisher) }
    }

    if ($apps.Count -eq 0) {
        Write-Host "ℹ️  No apps found matching the specified criteria." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "✅ Retrieved $($apps.Count) app(s)" -ForegroundColor Green

    switch ($OutputFormat) {
        'Table' {
            $apps | Select-Object displayName, publisher,
                @{N='Type'; E={ $_.'@odata.type' -replace '#microsoft.graph.','' }},
                @{N='Assigned'; E={ $_.isAssigned }},
                @{N='Modified'; E={ $_.lastModifiedDateTime }} |
                Format-Table -AutoSize
        }
        'List' {
            foreach ($app in $apps) {
                $appType = $app.'@odata.type' -replace '#microsoft.graph.', ''
                Write-Host "`n📦 $($app.displayName)" -ForegroundColor Yellow
                Write-Host "   App ID:    $($app.id)" -ForegroundColor White
                Write-Host "   Type:      $appType" -ForegroundColor White
                Write-Host "   Publisher: $($app.publisher)" -ForegroundColor White
                Write-Host "   Assigned:  $($app.isAssigned)" -ForegroundColor White
                Write-Host "   Modified:  $($app.lastModifiedDateTime)" -ForegroundColor White
                if ($app.description) {
                    $shortDesc = if ($app.description.Length -gt 80) { $app.description.Substring(0, 80) + "..." } else { $app.description }
                    Write-Host "   Desc:      $shortDesc" -ForegroundColor Gray
                }
            }
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-apps-$timestamp.json"
            $apps | ConvertTo-Json -Depth 5 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported $($apps.Count) apps to: $filePath" -ForegroundColor Green
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $filePath = "intune-apps-$timestamp.csv"
            $apps | Select-Object id, displayName, publisher,
                @{N='AppType'; E={ $_.'@odata.type' }},
                isAssigned, createdDateTime, lastModifiedDateTime |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported $($apps.Count) apps to: $filePath" -ForegroundColor Green
        }
    }

    Write-Host "`n📊 Summary: $($apps.Count) app(s) returned" -ForegroundColor Blue
}
catch {
    Write-Host "❌ Failed to retrieve Intune apps: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
