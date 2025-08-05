<#
.SYNOPSIS
    Creates an AWS Organizational Unit using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script creates an organizational unit under a specified parent (root or OU).
.PARAMETER ParentId
    The ID of the parent (root or OU).
.PARAMETER Name
    The name of the organizational unit.
.EXAMPLE
    .\aws-cli-create-organizational-unit.ps1 -ParentId r-1234 -Name "Finance"
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^(r|ou)-[a-zA-Z0-9]{4,}$')]
    [string]$ParentId,
    [Parameter(Mandatory)]
    [string]$Name
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws organizations create-organizational-unit --parent-id $ParentId --name $Name --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Organizational unit created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create organizational unit: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
