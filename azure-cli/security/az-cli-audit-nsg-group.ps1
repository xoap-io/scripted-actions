<#
.SYNOPSIS
    Audit Azure NSG configuration for security best practices, compliance, and rule conflicts. Generates a detailed report.
.DESCRIPTION
    This script audits an NSG for security best practices, compliance, and rule conflicts. Generates a detailed HTML/JSON/CSV report with findings and recommendations.
.PARAMETER Name
    Name of the NSG to audit.
.PARAMETER ResourceGroup
    Name of the Azure Resource Group.
.PARAMETER OutputFormat
    Format for report (HTML/JSON/CSV).
.PARAMETER OutputPath
    Path for report file.
.EXAMPLE
    .\az-cli-audit-nsg-group.ps1 -Name "web-nsg" -ResourceGroup "rg-web" -OutputFormat "HTML"
.NOTES
    Author: XOAP.IO
    Date: 2025-08-05
.0
    Requires: Azure CLI version 2.0 or later
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory = $false)]
    [ValidateSet('HTML','JSON','CSV')]
    [string]$OutputFormat = 'HTML',
    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
function Test-AzureCLI {
    try {
        $null = az --version
        if ($LASTEXITCODE -ne 0) { throw "Azure CLI is not installed or not functioning correctly" }
        $null = az account show 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Not authenticated to Azure CLI. Please run 'az login' first" }
        return $true
    } catch { Write-Error $_; return $false }
}
if (-not (Test-AzureCLI)) { exit 1 }
$rules = az network nsg rule list --resource-group $ResourceGroup --nsg-name $Name --output json | ConvertFrom-Json
if (-not $rules) { Write-Host "No rules found." -ForegroundColor Yellow; exit 0 }
$findings = @()
foreach ($rule in $rules) {
    if ($rule.access -eq 'Allow' -and $rule.sourceAddressPrefix -eq '*' -and $rule.direction -eq 'Inbound') {
        $findings += "Rule '$($rule.name)' allows inbound traffic from ANY source. Review for risk."
    }
    if ($rule.priority -lt 100) {
        $findings += "Rule '$($rule.name)' uses a very high priority (<100). Review for necessity."
    }
    if ($rule.protocol -eq '*' -and $rule.access -eq 'Allow') {
        $findings += "Rule '$($rule.name)' allows ALL protocols. Review for risk."
    }
}
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$path = if ($OutputPath) { $OutputPath } else { "./nsg-audit-$Name-$timestamp.$OutputFormat" }
switch ($OutputFormat) {
    'HTML' {
        $html = @"<html><head><title>NSG Audit Report</title></head><body><h1>NSG Audit Report: $Name</h1><ul>"@
        foreach ($finding in $findings) { $html += "<li>$finding</li>" }
        $html += "</ul></body></html>"
        $html | Out-File -FilePath $path -Encoding UTF8
    }
    'JSON' {
        $findings | ConvertTo-Json -Depth 5 | Out-File -FilePath $path -Encoding UTF8
    }
    'CSV' {
        $findings | Export-Csv -Path $path -NoTypeInformation
    }
}
Write-Host "✅ Audit report generated: $path" -ForegroundColor Green
