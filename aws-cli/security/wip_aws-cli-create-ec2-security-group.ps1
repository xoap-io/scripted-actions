<#
.SYNOPSIS
    This script creates an AWS EC2 security group.

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

.PARAMETER AwsSecurityGroupName
    Defines the name of the AWS EC2 security group.

.PARAMETER AwsSecurityGroupDescription
    Defines the description of the AWS EC2 security group.

.PARAMETER AwsVpcId
    Defines the ID of the AWS VPC.

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsSecurityGroupName,
    [Parameter(Mandatory)]
    [string]$AwsSecurityGroupDescription,
    [Parameter(Mandatory)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$AwsVpcId,
    [Parameter(Mandatory)]
    [ValidateSet('tcp','udp','icmp','all')]
    [string]$Protocol,
    [Parameter(Mandatory)]
    [ValidatePattern('^\d{1,5}$')]
    [string]$Port,
    [Parameter(Mandatory)]
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
    Write-Error "Unexpected error: $_"
    exit 1
}
