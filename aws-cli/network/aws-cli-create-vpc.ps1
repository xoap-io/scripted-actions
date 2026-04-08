<#
.SYNOPSIS
    Creates a new AWS VPC using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script creates a new VPC with a specified CIDR block. It uses robust parameter validation and error handling.
    Uses aws ec2 create-vpc to perform the operation.

.PARAMETER CidrBlock
    The IPv4 CIDR block for the VPC.

.EXAMPLE
    .\aws-cli-create-vpc.ps1 -CidrBlock 10.0.0.0/16

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-vpc.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The IPv4 CIDR block for the VPC.")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$CidrBlock
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    $result = aws ec2 create-vpc --cidr-block $CidrBlock --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ VPC created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        throw "Failed to create VPC: $result"
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
