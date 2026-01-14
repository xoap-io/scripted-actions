<#
.SYNOPSIS
    This script creates an AWS subnet.

.DESCRIPTION
    This script creates an AWS subnet. The script uses the following AWS CLI command:
    aws ec2 create-subnet --vpc-id $AwsVpcId --cidr-block $AwsCidrBlock --ipv6-cidr-block $AwsIpv6CidrBlock --tag-specifications $AwsTagSpecifications

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

.PARAMETER AwsVpcId
    Defines the ID of the AWS VPC.

.PARAMETER AwsCidrBlock
    Defines the CIDR block of the AWS subnet.

.PARAMETER AwsIpv6CidrBlock
    Defines the IPv6 CIDR block of the AWS subnet.

.PARAMETER AwsTagSpecifications
    Defines the tag specifications of the AWS subnet.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$AwsVpcId,
    [Parameter(Mandatory)]
    [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}/\d{1,2}$')]
    [string]$AwsCidrBlock,
    [Parameter(Mandatory)]
    [ValidatePattern('^([a-fA-F0-9:]+:+)+[a-fA-F0-9]+/\d{1,3}$')]
    [string]$AwsIpv6CidrBlock,
    [Parameter(Mandatory)]
    [string]$AwsTagSpecifications
)


$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $result = aws ec2 create-subnet `
        --vpc-id $AwsVpcId `
        --cidr-block $AwsCidrBlock `
        --ipv6-cidr-block $AwsIpv6CidrBlock `
        --tag-specifications $AwsTagSpecifications `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Subnet created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create subnet: $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
