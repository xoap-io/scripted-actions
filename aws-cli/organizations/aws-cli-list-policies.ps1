<#
.SYNOPSIS
    Lists all policies in the AWS organization.
.DESCRIPTION
    This script lists all policies in the AWS organization using the latest AWS CLI (v2.16+).
.EXAMPLE
    .\aws-cli-list-policies.ps1
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws organizations list-policies --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Policies listed successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to list policies: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
