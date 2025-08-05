<#
.SYNOPSIS
    Creates an AWS EC2 security group using the latest AWS CLI (v2.16+).
.DESCRIPTION
    This script creates a security group for a specified VPC.
.PARAMETER GroupName
    The name of the security group.
.PARAMETER Description
    The description of the security group.
.PARAMETER VpcId
    The ID of the VPC for the security group.
.EXAMPLE
    .\aws-cli-create-security-group.ps1 -GroupName myGroup -Description "My SG" -VpcId vpc-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9-_]{1,255}$')]
    [string]$GroupName,
    [Parameter(Mandatory)]
    [string]$Description,
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
    $result = aws ec2 create-security-group --group-name $GroupName --description $Description --vpc-id $VpcId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Security group created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create security group: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
