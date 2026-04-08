<#
.SYNOPSIS
    List Microsoft Intune device configuration profiles and settings catalog policies
    via the Microsoft Graph API.

.DESCRIPTION
    This script retrieves device configuration profiles and settings catalog policies from
    Microsoft Intune using the Microsoft Graph API. Supports filtering by platform and
    policy type, with multiple output format options.
    Authentication is handled externally by XOAP using an App Registration.

    The script uses the Microsoft Graph API endpoints:
    - GET /deviceManagement/deviceConfigurations
    - GET /deviceManagement/configurationPolicies (Settings Catalog)

.PARAMETER PolicySource
    Which policy source to retrieve. Valid values: ConfigurationProfiles, SettingsCatalog, All.

.PARAMETER Platform
    Filter by target platform (applies to Configuration Profiles).
    Valid values: All, windows10, ios, android, macOS, windowsPhone81.

.PARAMETER OutputFormat
    Output format for results. Valid values: Table, List, JSON, CSV.

.EXAMPLE
    .\msgraph-get-intune-config-policies.ps1
    Lists all configuration profiles and settings catalog policies.

.EXAMPLE
    .\msgraph-get-intune-config-policies.ps1 -PolicySource SettingsCatalog -OutputFormat Table
    Lists only Settings Catalog policies in table format.

.EXAMPLE
    .\msgraph-get-intune-config-policies.ps1 -PolicySource ConfigurationProfiles -Platform windows10 -OutputFormat CSV
    Exports all Windows 10 configuration profiles to a CSV file in the current directory.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: Microsoft.Graph PowerShell SDK
    Required Permissions: DeviceManagementConfiguration.Read.All (Application)

.LINK
    https://learn.microsoft.com/en-us/graph/api/intune-deviceconfig-deviceconfiguration-list

.COMPONENT
    Microsoft Graph, Microsoft Intune
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Policy source to retrieve")]
    [ValidateSet('ConfigurationProfiles', 'SettingsCatalog', 'All')]
    [string]$PolicySource = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Filter by target platform (Configuration Profiles only)")]
    [ValidateSet('All', 'windows10', 'ios', 'android', 'macOS', 'windowsPhone81')]
    [string]$Platform = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Output format")]
    [ValidateSet('Table', 'List', 'JSON', 'CSV')]
    [string]$OutputFormat = 'Table'
)

# Set strict error handling
$ErrorActionPreference = 'Stop'

function Get-ConfigurationProfiles {
    Write-Host "🔄 Retrieving configuration profiles..." -ForegroundColor Cyan
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations?`$select=id,displayName,description,@odata.type,createdDateTime,lastModifiedDateTime,version"

    $response = Invoke-MgGraphRequest -Uri $uri -Method GET
    $profiles = [System.Collections.Generic.List[PSObject]]::new()
    $profiles.AddRange([PSObject[]]$response.value)

    $nextLink = $response.'@odata.nextLink'
    while ($nextLink) {
        Write-Host "   ↳ Fetching next page..." -ForegroundColor Gray
        $pageResponse = Invoke-MgGraphRequest -Uri $nextLink -Method GET
        $profiles.AddRange([PSObject[]]$pageResponse.value)
        $nextLink = $pageResponse.'@odata.nextLink'
    }

    # Filter by platform
    if ($Platform -ne 'All') {
        $platformTypeMap = @{
            'windows10'     = 'windows10'
            'ios'           = 'ios'
            'android'       = 'android'
            'macOS'         = 'macOS'
            'windowsPhone81' = 'windowsPhone81'
        }
        $platformKey = $platformTypeMap[$Platform]
        $profiles = $profiles | Where-Object { $_.'@odata.type' -match $platformKey }
        Write-Host "🔍 Filtered to platform: $Platform" -ForegroundColor Cyan
    }

    return $profiles | ForEach-Object {
        $_ | Add-Member -NotePropertyName 'PolicySource' -NotePropertyValue 'ConfigurationProfile' -PassThru
    }
}

function Get-SettingsCatalogPolicies {
    Write-Host "🔄 Retrieving Settings Catalog policies..." -ForegroundColor Cyan
    $uri = "https://graph.microsoft.com/v1.0/deviceManagement/configurationPolicies?`$select=id,name,description,platforms,technologies,createdDateTime,lastModifiedDateTime,settingCount,isAssigned"

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

    return $policies | ForEach-Object {
        # Settings Catalog uses 'name' instead of 'displayName'
        $_ | Add-Member -NotePropertyName 'displayName'  -NotePropertyValue $_.name -PassThru |
             Add-Member -NotePropertyName 'PolicySource' -NotePropertyValue 'SettingsCatalog' -PassThru
    }
}

function Write-PolicyOutput {
    param([array]$Policies, [string]$Format, [string]$SourceLabel)

    if ($Policies.Count -eq 0) {
        Write-Host "ℹ️  No $SourceLabel found." -ForegroundColor Yellow
        return
    }

    Write-Host "✅ $SourceLabel : $($Policies.Count) item(s)" -ForegroundColor Green

    switch ($Format) {
        'Table' {
            $Policies | Select-Object displayName,
                @{N='Platform'; E={ if ($_.platforms) { $_.platforms } else { $_.'@odata.type' -replace '#microsoft.graph.','' } }},
                PolicySource,
                @{N='Settings'; E={ if ($_.settingCount) { $_.settingCount } else { 'N/A' } }},
                @{N='Modified'; E={ $_.lastModifiedDateTime }} |
                Format-Table -AutoSize
        }
        'List' {
            foreach ($policy in $Policies) {
                $platform = if ($policy.platforms) { $policy.platforms } else { $policy.'@odata.type' -replace '#microsoft.graph.','' }
                Write-Host "`n📋 $($policy.displayName)" -ForegroundColor Yellow
                Write-Host "   ID:       $($policy.id)" -ForegroundColor White
                Write-Host "   Source:   $($policy.PolicySource)" -ForegroundColor White
                Write-Host "   Platform: $platform" -ForegroundColor White
                Write-Host "   Modified: $($policy.lastModifiedDateTime)" -ForegroundColor White
                if ($policy.settingCount) {
                    Write-Host "   Settings: $($policy.settingCount)" -ForegroundColor White
                }
                if ($policy.description) {
                    Write-Host "   Desc:     $($policy.description)" -ForegroundColor White
                }
            }
        }
        'JSON' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $label = $SourceLabel -replace ' ', '-'
            $filePath = "intune-config-$label-$timestamp.json"
            $Policies | ConvertTo-Json -Depth 10 | Out-File -FilePath $filePath -Encoding UTF8
            Write-Host "✅ Exported to: $filePath" -ForegroundColor Green
        }
        'CSV' {
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $label = $SourceLabel -replace ' ', '-'
            $filePath = "intune-config-$label-$timestamp.csv"
            $Policies | Select-Object id, displayName, PolicySource,
                @{N='Platform'; E={ if ($_.platforms) { $_.platforms } else { $_.'@odata.type' } }},
                description, createdDateTime, lastModifiedDateTime |
                Export-Csv -Path $filePath -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Exported to: $filePath" -ForegroundColor Green
        }
    }
}

try {
    Write-Host "⚙️  Intune Configuration Policy Listing" -ForegroundColor Blue
    Write-Host "=======================================" -ForegroundColor Blue

    $allResults = @()

    if ($PolicySource -in 'ConfigurationProfiles', 'All') {
        $profiles = Get-ConfigurationProfiles
        Write-PolicyOutput -Policies $profiles -Format $OutputFormat -SourceLabel "Configuration Profiles"
        $allResults += $profiles
    }

    if ($PolicySource -in 'SettingsCatalog', 'All') {
        $catalogPolicies = Get-SettingsCatalogPolicies
        Write-PolicyOutput -Policies $catalogPolicies -Format $OutputFormat -SourceLabel "Settings Catalog Policies"
        $allResults += $catalogPolicies
    }

    Write-Host "`n📊 Total: $($allResults.Count) policy/policies retrieved" -ForegroundColor Blue
}
catch {
    Write-Host "❌ Failed to retrieve configuration policies: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
