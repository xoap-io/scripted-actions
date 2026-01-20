<#
.SYNOPSIS
    Removes an AWS account from the organization.
.DESCRIPTION
    This script removes an account from the AWS organization using the latest AWS CLI (v2.16+).
.PARAMETER AccountId
    The ID of the AWS account to remove.
.EXAMPLE
    .\aws-cli-remove-account.ps1 -AccountId 123456789012
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{12}$')]
    [string]$AccountId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws organizations remove-account-from-organization --account-id $AccountId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Account removed successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to remove account: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
