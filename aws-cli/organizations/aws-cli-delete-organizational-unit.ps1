<#
.SYNOPSIS
    Deletes an AWS Organizational Unit using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script deletes an organizational unit by its ID.
.PARAMETER OrganizationalUnitId
    The ID of the organizational unit to delete.
.EXAMPLE
    .\aws-cli-delete-organizational-unit.ps1 -OrganizationalUnitId ou-1234abcd
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ou-[a-zA-Z0-9]{4,}$')]
    [string]$OrganizationalUnitId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws organizations delete-organizational-unit --organizational-unit-id $OrganizationalUnitId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Organizational unit deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete organizational unit: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
