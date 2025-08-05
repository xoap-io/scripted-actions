<#
.SYNOPSIS
    Lists all organizational units for a parent in AWS Organizations.
.DESCRIPTION
    This script lists all organizational units for a specified parent (root or OU) using the latest AWS CLI (v2.16+).
.PARAMETER ParentId
    The ID of the parent (root or OU).
.EXAMPLE
    .\aws-cli-list-organizational-units.ps1 -ParentId r-1234
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^(r|ou)-[a-zA-Z0-9]{4,}$')]
    [string]$ParentId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws organizations list-organizational-units-for-parent --parent-id $ParentId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Organizational units listed successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to list organizational units: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
