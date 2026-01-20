<#
.SYNOPSIS
    Describes an AWS account in the organization.
.DESCRIPTION
    This script describes a specific account in the AWS organization using the latest AWS CLI (v2.16+).
.PARAMETER AccountId
    The ID of the AWS account to describe.
.EXAMPLE
    .\aws-cli-describe-account.ps1 -AccountId 123456789012
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
    $result = aws organizations describe-account --account-id $AccountId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Account described successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to describe account: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
