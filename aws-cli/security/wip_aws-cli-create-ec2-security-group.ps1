<#
.SYNOPSIS
    Creates an AWS EC2 security group and authorizes an ingress rule.

.DESCRIPTION
    This script creates an AWS EC2 security group and adds an ingress rule using the AWS CLI.
    Uses the following AWS CLI commands:
    aws ec2 create-security-group
    aws ec2 authorize-security-group-ingress

.PARAMETER AwsSecurityGroupName
    Defines the name of the AWS EC2 security group.

.PARAMETER AwsSecurityGroupDescription
    Defines the description of the AWS EC2 security group.

.PARAMETER AwsVpcId
    Defines the ID of the AWS VPC.

.PARAMETER Protocol
    The protocol for the ingress rule (tcp, udp, icmp, all).

.PARAMETER Port
    The port number for the ingress rule.

.PARAMETER Cidr
    The CIDR block for the ingress rule.

.EXAMPLE
    .\wip_aws-cli-create-ec2-security-group.ps1 -AwsSecurityGroupName "my-sg" -AwsSecurityGroupDescription "My Security Group" -AwsVpcId "vpc-12345678" -Protocol "tcp" -Port "443" -Cidr "0.0.0.0/0"

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
    AWS CLI Security
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The name of the AWS EC2 security group")]
    [string]$AwsSecurityGroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The description of the AWS EC2 security group")]
    [string]$AwsSecurityGroupDescription,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS VPC")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$AwsVpcId,

    [Parameter(Mandatory = $true, HelpMessage = "The protocol for the ingress rule (tcp, udp, icmp, all)")]
    [ValidateSet('tcp', 'udp', 'icmp', 'all')]
    [string]$Protocol,

    [Parameter(Mandatory = $true, HelpMessage = "The port number for the ingress rule")]
    [ValidatePattern('^\d{1,5}$')]
    [string]$Port,

    [Parameter(Mandatory = $true, HelpMessage = "The CIDR block for the ingress rule")]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$Cidr
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $sgResult = aws ec2 create-security-group --group-name $AwsSecurityGroupName --description $AwsSecurityGroupDescription --vpc-id $AwsVpcId --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Security group created successfully." -ForegroundColor Green
        Write-Host $sgResult
        $sgId = (ConvertFrom-Json $sgResult).GroupId
        $ingressResult = aws ec2 authorize-security-group-ingress --group-id $sgId --protocol $Protocol --port $Port --cidr $Cidr --output json 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Ingress rule authorized successfully." -ForegroundColor Green
            Write-Host $ingressResult
        } else {
            Write-Error "Failed to authorize ingress rule: $ingressResult"
            exit $LASTEXITCODE
        }
    } else {
        Write-Error "Failed to create security group: $sgResult"
        exit $LASTEXITCODE
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
