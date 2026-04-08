<#
.SYNOPSIS
    Creates an AWS Route Table using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script creates a route table for a specified VPC.
    Uses aws ec2 create-route-table to perform the operation.

.PARAMETER VpcId
    The ID of the VPC for the route table.

.EXAMPLE
    .\aws-cli-create-route-table.ps1 -VpcId vpc-12345678

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/create-route-table.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the VPC for the route table.")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    $result = aws ec2 create-route-table --vpc-id $VpcId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Route Table created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        throw "Failed to create Route Table: $result"
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
