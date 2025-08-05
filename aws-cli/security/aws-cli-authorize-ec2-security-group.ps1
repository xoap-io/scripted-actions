<#
.SYNOPSIS
    Authorize an AWS EC2 security group.

.DESCRIPTION
    This script creates an AWS EC2 security group. The script uses the following AWS CLI commands:
    aws ec2 create-security-group --group-name $AwsSecurityGroupName --description $AwsSecurityGroupDescription --vpc-id $AwsVpcId
 
    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    AWS CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AwsSecurityGroupId
    Defines the ID of the AWS EC2 security group.

.PARAMETER AwsSecurityGroupProtocol
    Defines the protocol of the AWS EC2 security group.

.PARAMETER AwsSecurityGroupPort
    Defines the port of the AWS EC2 security group.

.PARAMETER AwsSecurityGroupCidr
    Defines the CIDR of the AWS EC2 security group.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$AwsSecurityGroupId,
    [Parameter(Mandatory)]
    [ValidateSet('tcp','udp','icmp','all')]
    [string]$AwsSecurityGroupProtocol,
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{1,5}$')]
    [string]$AwsSecurityGroupPort
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
    Write-Error "Unexpected error: $_"
    exit 1
}
