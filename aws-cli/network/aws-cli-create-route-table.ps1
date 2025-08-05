<#
.SYNOPSIS
    Creates an AWS Route Table using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script creates a route table for a specified VPC.
.PARAMETER VpcId
    The ID of the VPC for the route table.
.EXAMPLE
    .\aws-cli-create-route-table.ps1 -VpcId vpc-12345678
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
    $result = aws ec2 create-route-table --vpc-id $VpcId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Route Table created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create Route Table: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
