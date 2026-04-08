<#
.SYNOPSIS
    Authorizes an ingress rule for an AWS EC2 security group.

.DESCRIPTION
    This script adds an ingress rule to an AWS EC2 security group using the AWS CLI.
    Uses the following AWS CLI command:
    aws ec2 authorize-security-group-ingress

.PARAMETER AwsSecurityGroupId
    Defines the ID of the AWS EC2 security group.

.PARAMETER AwsSecurityGroupProtocol
    Defines the protocol of the AWS EC2 security group.

.PARAMETER AwsSecurityGroupPort
    Defines the port of the AWS EC2 security group.

.PARAMETER AwsSecurityGroupCidr
    Defines the CIDR of the AWS EC2 security group.

.EXAMPLE
    .\aws-cli-authorize-ec2-security-group.ps1 -AwsSecurityGroupId "sg-12345678" -AwsSecurityGroupProtocol "tcp" -AwsSecurityGroupPort "443" -AwsSecurityGroupCidr "0.0.0.0/0"

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/authorize-security-group-ingress.html

.COMPONENT
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS EC2 security group")]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$AwsSecurityGroupId,

    [Parameter(Mandatory = $true, HelpMessage = "The protocol of the AWS EC2 security group (tcp, udp, icmp, all)")]
    [ValidateSet('tcp', 'udp', 'icmp', 'all')]
    [string]$AwsSecurityGroupProtocol,

    [Parameter(Mandatory = $true, HelpMessage = "The port of the AWS EC2 security group")]
    [ValidatePattern('^\d{1,5}$')]
    [string]$AwsSecurityGroupPort,

    [Parameter(Mandatory = $true, HelpMessage = "The CIDR block for the AWS EC2 security group rule")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$AwsSecurityGroupCidr
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws ec2 authorize-security-group-ingress `
        --group-id $AwsSecurityGroupId `
        --protocol $AwsSecurityGroupProtocol `
        --port $AwsSecurityGroupPort `
        --cidr $AwsSecurityGroupCidr `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Security group ingress rule authorized successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to authorize security group ingress: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
