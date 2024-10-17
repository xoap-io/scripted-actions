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
    [string]$AwsSecurityGroupId = "sg-1234567890abcdef0",
    [Parameter(Mandatory)]
    [string]$AwsSecurityGroupProtocol = "tcp",
    [Parameter(Mandatory)]
    [string]$AwsSecurityGroupPort = "80",
    [Parameter(Mandatory)]
    [string]$AwsSecurityGroupCidr = "10.0.0.0/16"
    
    )

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"

aws ec2 authorize-security-group-ingress `
    --group-id $AwsSecurityGroupId `
    --protocol $AwsSecurityGroupProtocol `
    --port $AwsSecurityGroupPort `
    --cidr $AwsSecurityGroupCidr
