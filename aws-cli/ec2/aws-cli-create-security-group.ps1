<#
.SYNOPSIS
    Creates an AWS EC2 security group using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script creates a security group for a specified VPC.
    Uses aws ec2 create-security-group to perform the operation.

.PARAMETER GroupName
    The name of the security group.

.PARAMETER Description
    The description of the security group.

.PARAMETER VpcId
    The ID of the VPC for the security group.

.EXAMPLE
    .\aws-cli-create-security-group.ps1 -GroupName myGroup -Description "My SG" -VpcId vpc-12345678

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-security-group.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the security group.")]
    [ValidatePattern('^[a-zA-Z0-9-_]{1,255}$')]
    [string]$GroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The description of the security group.")]
    [string]$Description,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC for the security group.")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    $result = aws ec2 create-security-group --group-name $GroupName --description $Description --vpc-id $VpcId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Security group created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        throw "Failed to create security group: $result"
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
