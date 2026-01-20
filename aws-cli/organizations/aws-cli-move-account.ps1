<#
.SYNOPSIS
    Moves an AWS account between organizational units using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script moves an account from one parent (root or OU) to another.
.PARAMETER AccountId
    The ID of the AWS account to move.
.PARAMETER SourceParentId
    The ID of the source parent (root or OU).
.PARAMETER DestinationParentId
    The ID of the destination parent (root or OU).
.EXAMPLE
    .\aws-cli-move-account.ps1 -AccountId 123456789012 -SourceParentId r-1234 -DestinationParentId ou-5678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{12}$')]
    [string]$AccountId,
    [Parameter(Mandatory)]
    [ValidatePattern('^(r|ou)-[a-zA-Z0-9]{4,}$')]
    [string]$SourceParentId,
    [Parameter(Mandatory)]
    [ValidatePattern('^(r|ou)-[a-zA-Z0-9]{4,}$')]
    [string]$DestinationParentId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws organizations move-account --account-id $AccountId --source-parent-id $SourceParentId --destination-parent-id $DestinationParentId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Account moved successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to move account: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
