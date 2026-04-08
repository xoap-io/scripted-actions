<#
.SYNOPSIS
    Revokes an egress rule from an AWS EC2 security group.

.DESCRIPTION
    This script removes an egress rule from a security group using the AWS CLI.
    Uses the following AWS CLI command:
    aws ec2 revoke-security-group-egress

.PARAMETER GroupId
    The ID of the security group.

.PARAMETER Protocol
    The protocol (tcp, udp, icmp, all).

.PARAMETER Port
    The port number.

.PARAMETER Cidr
    The CIDR block.

.EXAMPLE
    .\aws-cli-revoke-security-group-egress.ps1 -GroupId "sg-12345678" -Protocol "tcp" -Port "443" -Cidr "0.0.0.0/0"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/revoke-security-group-egress.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the security group")]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$GroupId,

    [Parameter(Mandatory = $true, HelpMessage = "The protocol (tcp, udp, icmp, all)")]
    [ValidateSet('tcp', 'udp', 'icmp', 'all')]
    [string]$Protocol,

    [Parameter(Mandatory = $true, HelpMessage = "The port number")]
    [ValidatePattern('^\d{1,5}$')]
    [string]$Port,

    [Parameter(Mandatory = $true, HelpMessage = "The CIDR block")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Cidr
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws ec2 revoke-security-group-egress --group-id $GroupId --protocol $Protocol --port $Port --cidr $Cidr --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Egress rule revoked successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to revoke egress rule: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
