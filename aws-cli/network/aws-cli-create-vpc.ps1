<#
.SYNOPSIS
    Creates a new AWS VPC using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script creates a new VPC with a specified CIDR block. It uses robust parameter validation and error handling.
.PARAMETER CidrBlock
    The IPv4 CIDR block for the VPC.
.EXAMPLE
    .\aws-cli-create-vpc.ps1 -CidrBlock 10.0.0.0/16
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$CidrBlock
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 create-vpc --cidr-block $CidrBlock --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "VPC created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create VPC: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
