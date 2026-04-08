<#
.SYNOPSIS
    Deletes an AWS Internet Gateway using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script detaches and deletes an Internet Gateway from a VPC.
    Uses aws ec2 detach-internet-gateway and aws ec2 delete-internet-gateway to perform the operations.

.PARAMETER InternetGatewayId
    The ID of the Internet Gateway to delete.

.PARAMETER VpcId
    The ID of the VPC to detach from (optional).

.EXAMPLE
    .\aws-cli-delete-internet-gateway.ps1 -InternetGatewayId igw-12345678 -VpcId vpc-12345678

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/delete-internet-gateway.html

.COMPONENT
    AWS CLI Network
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the Internet Gateway to delete.")]
    [ValidatePattern('^igw-[a-zA-Z0-9]{8,}$')]
    [string]$InternetGatewayId,

    [Parameter(Mandatory = $false, HelpMessage = "The ID of the VPC to detach from (optional).")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    if ($VpcId) {
        $detachResult = aws ec2 detach-internet-gateway --internet-gateway-id $InternetGatewayId --vpc-id $VpcId --output json 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to detach Internet Gateway: $detachResult"
        }
    }
    $result = aws ec2 delete-internet-gateway --internet-gateway-id $InternetGatewayId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Internet Gateway deleted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        throw "Failed to delete Internet Gateway: $result"
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
