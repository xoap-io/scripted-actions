<#
.SYNOPSIS
    Deletes an AWS Internet Gateway using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script detaches and deletes an Internet Gateway from a VPC.
.PARAMETER InternetGatewayId
    The ID of the Internet Gateway to delete.
.PARAMETER VpcId
    The ID of the VPC to detach from (optional).
.EXAMPLE
    .\aws-cli-delete-internet-gateway.ps1 -InternetGatewayId igw-12345678 -VpcId vpc-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^igw-[a-zA-Z0-9]{8,}$')]
    [string]$InternetGatewayId,
    [Parameter()]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}
try {
    if ($VpcId) {
        $detachResult = aws ec2 detach-internet-gateway --internet-gateway-id $InternetGatewayId --vpc-id $VpcId --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to detach Internet Gateway: $detachResult"
            exit $LASTEXITCODE
        }
    }
    $result = aws ec2 delete-internet-gateway --internet-gateway-id $InternetGatewayId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Internet Gateway deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to delete Internet Gateway: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
