<#
.SYNOPSIS
    Deletes an AWS EC2 key pair using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script deletes a key pair by name, with parameter validation and error handling.
.PARAMETER KeyPairName
    The name of the key pair to delete.
.EXAMPLE
    .\aws-cli-delete-key-pair.ps1 -KeyPairName myKey
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9-_]{1,255}$')]
    [string]$KeyPairName
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 delete-key-pair --key-name $KeyPairName --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Key pair deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete key pair: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
