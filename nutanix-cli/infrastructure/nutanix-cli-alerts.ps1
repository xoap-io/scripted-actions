<#
.SYNOPSIS
    List and manage Nutanix cluster alerts using the Prism Central REST API v3.

.DESCRIPTION
    This script retrieves Nutanix cluster alerts using the Prism Central REST API v3
    by calling POST /alerts/list. Results can be filtered by severity level. Optionally,
    all retrieved alerts can be acknowledged with the -AcknowledgeAll switch.
    Authentication uses HTTP Basic auth with -SkipCertificateCheck (PowerShell 7+).

.PARAMETER PrismCentralHost
    The FQDN or IP address of the Prism Central instance.

.PARAMETER Username
    The Prism Central username for authentication.

.PARAMETER Password
    The Prism Central password as a SecureString.

.PARAMETER Severity
    Filter alerts by severity. Valid values: All, Critical, Warning, Info.
    Default: All

.PARAMETER AcknowledgeAll
    Acknowledge all retrieved alerts after listing them.

.PARAMETER OutputFormat
    Output format for the results. Valid values: Table, JSON.
    Default: Table

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-alerts.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass

    List all alerts as a table.

.EXAMPLE
    $pass = Read-Host -AsSecureString "Password"
    .\nutanix-cli-alerts.ps1 -PrismCentralHost "pc.domain.com" -Username "admin" -Password $pass -Severity Critical -AcknowledgeAll -OutputFormat JSON

    List critical alerts as JSON and acknowledge them all.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: PowerShell 7+ (for -SkipCertificateCheck support)

.LINK
    https://www.nutanix.dev/reference/prism_central/v3/

.COMPONENT
    Nutanix REST API PowerShell
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The FQDN or IP address of the Prism Central instance.")]
    [ValidateNotNullOrEmpty()]
    [string]$PrismCentralHost,

    [Parameter(Mandatory = $true, HelpMessage = "The Prism Central username for authentication.")]
    [ValidateNotNullOrEmpty()]
    [string]$Username,

    [Parameter(Mandatory = $true, HelpMessage = "The Prism Central password as a SecureString.")]
    [ValidateNotNull()]
    [SecureString]$Password,

    [Parameter(Mandatory = $false, HelpMessage = "Filter alerts by severity. Valid values: All, Critical, Warning, Info.")]
    [ValidateSet('All', 'Critical', 'Warning', 'Info')]
    [string]$Severity = 'All',

    [Parameter(Mandatory = $false, HelpMessage = "Acknowledge all retrieved alerts after listing them.")]
    [switch]$AcknowledgeAll,

    [Parameter(Mandatory = $false, HelpMessage = "Output format for the results. Valid values: Table, JSON.")]
    [ValidateSet('Table', 'JSON')]
    [string]$OutputFormat = 'Table'
)

$ErrorActionPreference = 'Stop'

$baseUrl = "https://$PrismCentralHost`:9440/api/nutanix/v3"
$bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
$encodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${plainPassword}"))
$headers = @{
    Authorization  = "Basic $encodedAuth"
    'Content-Type' = 'application/json'
}

function Invoke-NutanixApi {
    param([string]$Method, [string]$Endpoint, [hashtable]$Body)
    $invokeParams = @{
        Method               = $Method
        Uri                  = "$baseUrl$Endpoint"
        Headers              = $headers
        SkipCertificateCheck = $true
    }
    if ($Body) { $invokeParams.Body = ($Body | ConvertTo-Json -Depth 10) }
    return Invoke-RestMethod @invokeParams
}

try {
    Write-Host "🚀 Starting Nutanix alerts retrieval..." -ForegroundColor Green
    Write-Host "ℹ️  Prism Central: $PrismCentralHost" -ForegroundColor Yellow
    Write-Host "ℹ️  Severity Filter: $Severity" -ForegroundColor Yellow

    # Build list body
    $listBody = @{
        kind   = 'alert'
        length = 500
    }

    if ($Severity -ne 'All') {
        $listBody.filter = "severity==$($Severity.ToUpper())"
    }

    Write-Host "🔍 Retrieving alerts..." -ForegroundColor Cyan
    $response = Invoke-NutanixApi -Method POST -Endpoint '/alerts/list' -Body $listBody

    $alerts = $response.entities
    $totalCount = $response.metadata.total_matches

    Write-Host "✅ Retrieved $($alerts.Count) alert(s) (Total matching: $totalCount)." -ForegroundColor Green

    if ($alerts.Count -eq 0) {
        Write-Host "ℹ️  No alerts found for filter '$Severity'." -ForegroundColor Yellow
        return
    }

    # Build output objects
    $output = $alerts | ForEach-Object {
        [PSCustomObject]@{
            UUID          = $_.metadata.uuid
            Severity      = $_.status.resources.severity
            Title         = $_.status.resources.title
            Message       = ($_.status.resources.message -replace '\s+', ' ')
            Acknowledged  = $_.status.resources.acknowledged
            CreatedTime   = $_.metadata.creation_time
        }
    }

    if ($OutputFormat -eq 'JSON') {
        $output | ConvertTo-Json -Depth 5
    }
    else {
        $output | Format-Table -AutoSize
    }

    # Acknowledge all if requested
    if ($AcknowledgeAll) {
        Write-Host "🔧 Acknowledging all $($alerts.Count) retrieved alert(s)..." -ForegroundColor Cyan
        $acknowledgedCount = 0
        foreach ($alert in $alerts) {
            try {
                $uuid = $alert.metadata.uuid
                $ackBody = @{ acknowledged = $true }
                Invoke-NutanixApi -Method PUT -Endpoint "/alerts/$uuid" -Body $ackBody | Out-Null
                $acknowledgedCount++
            }
            catch {
                Write-Host "⚠️  Failed to acknowledge alert $($alert.metadata.uuid): $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
        Write-Host "✅ Acknowledged $acknowledgedCount alert(s)." -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($plainPassword) { $plainPassword = $null }
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
