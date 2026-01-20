<#
.SYNOPSIS
    Associates an AWS Route Table with a Subnet using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script associates a route table with a subnet.
.PARAMETER RouteTableId
    The ID of the route table.
.PARAMETER SubnetId
    The ID of the subnet.
.EXAMPLE
    .\aws-cli-associate-route-table.ps1 -RouteTableId rtb-12345678 -SubnetId subnet-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^rtb-[a-zA-Z0-9]{8,}$')]
    [string]$RouteTableId,
    [Parameter(Mandatory)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    $result = aws ec2 associate-route-table --route-table-id $RouteTableId --subnet-id $SubnetId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Route Table associated successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to associate Route Table: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
