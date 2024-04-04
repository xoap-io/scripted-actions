<#
.SYNOPSIS
    This script creates an EC2 instance in AWS.

.DESCRIPTION
    This script creates an EC2 instance in AWS. The script uses the following AWS CLI command:
    aws ec2 run-instances --image-id $AwsAmiId --count $AwsInstanceCount --instance-type $AwsInstanceType --key-name $AwsKeyPairName --security-group-ids $AwsSecurityGroupId --subnet-id $AwsSubnetId

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

.PARAMETER AwsAmiId
    Defines the ID of the Amazon Machine Image (AMI).

.PARAMETER AwsInstanceCount
    Defines the number of instances to launch.

.PARAMETER AwsInstanceType
    Defines the type of instance to launch.

.PARAMETER AwsKeyPairName
    Defines the name of the key pair.

.PARAMETER AwsSecurityGroupId
    Defines the ID of the security group.

.PARAMETER AwsSubnetId
    Defines the ID of the subnet.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AwsAmiId,
    [Parameter(Mandatory)]
    [int]$AwsInstanceCount,
    [Parameter(Mandatory)]
    [string]$AwsInstanceType,
    [Parameter(Mandatory)]
    [string]$AwsKeyPairName,
    [Parameter(Mandatory)]
    [string]$AwsSecurityGroupId 
)

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"


aws ec2 run-instances `
    --image-id $AwsAmiId `
    --count $AwsInstanceCount `
    --instance-type $AwsInstanceType `
    --key-name $AwsKeyPairName `
    --security-group-ids $AwsSecurityGroupId `
    --subnet-id $AwsSubnetId 
