<#
.SYNOPSIS
    Deletes an AWS VPC using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script deletes a VPC by its ID. It uses robust parameter validation and error handling.
.PARAMETER VpcId
    The ID of the VPC to delete.
.EXAMPLE
    .\aws-cli-delete-vpc.ps1 -VpcId vpc-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 delete-vpc --vpc-id $VpcId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "VPC deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete VPC: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
