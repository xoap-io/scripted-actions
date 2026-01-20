<#
.SYNOPSIS
    Attaches a policy to a target in AWS Organizations.
.DESCRIPTION
    This script attaches a policy to a target (account, OU, or root) using the latest AWS CLI (v2.16+).
.PARAMETER PolicyId
    The ID of the policy to attach.
.PARAMETER TargetId
    The ID of the target (account, OU, or root).
.EXAMPLE
    .\aws-cli-attach-policy.ps1 -PolicyId p-12345678 -TargetId r-1234
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^p-[a-zA-Z0-9]{8,}$')]
    [string]$PolicyId,
    [Parameter(Mandatory)]
    [ValidatePattern('^(r|ou|\d{12})-[a-zA-Z0-9]{4,}$|^\d{12}$')]
    [string]$TargetId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws organizations attach-policy --policy-id $PolicyId --target-id $TargetId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Policy attached successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to attach policy: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
