<#
.SYNOPSIS
    Creates an AWS Internet Gateway using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script creates an Internet Gateway and optionally attaches it to a VPC.
.PARAMETER VpcId
    The ID of the VPC to attach the Internet Gateway to (optional).
.EXAMPLE
    .\aws-cli-create-internet-gateway.ps1 -VpcId vpc-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
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
    $igwResult = aws ec2 create-internet-gateway --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Internet Gateway created successfully." -ForegroundColor Green
        Write-Host $igwResult
        if ($VpcId) {
            $igwId = (ConvertFrom-Json $igwResult).InternetGateway.InternetGatewayId
            $attachResult = aws ec2 attach-internet-gateway --internet-gateway-id $igwId --vpc-id $VpcId --output json 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Internet Gateway attached to VPC successfully." -ForegroundColor Green
                Write-Host $attachResult
            } else {
                Write-Error "Failed to attach Internet Gateway: $attachResult"
                exit $LASTEXITCODE
            }
        }
    } else {
        Write-Error "Failed to create Internet Gateway: $igwResult"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
