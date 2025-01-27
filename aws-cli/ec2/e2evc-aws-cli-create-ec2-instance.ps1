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
    [string]$AwsAmiId = "myAmiId",
    [Parameter(Mandatory)]
    [int]$AwsInstanceCount = 1,
    [Parameter(Mandatory)]
    [ValidateSet('t2.micro', 't2.small', 't2.medium', 't2.large', 'm4.large', 'm4.xlarge', 'm4.2xlarge', 'm4.4xlarge', 'm4.10xlarge', 'm4.16xlarge', 'm5.large', 'm5.xlarge', 'm5.2xlarge', 'm5.4xlarge', 'm5.12xlarge', 'm5.24xlarge', 'm5d.large', 'm5d.xlarge', 'm5d.2xlarge', 'm5d.4xlarge', 'm5d.12xlarge', 'm5d.24xlarge', 'c4.large', 'c4.xlarge', 'c4.2xlarge', 'c4.4xlarge', 'c4.8xlarge', 'c5.large', 'c5.xlarge', 'c5.2xlarge', 'c5.4xlarge', 'c5.9xlarge', 'c5.18xlarge', 'c5d.large', 'c5d.xlarge', 'c5d.2xlarge', 'c5d.4xlarge', 'c5d.9xlarge', 'c5d.18xlarge', 'r4.large', 'r4.xlarge', 'r4.2xlarge', 'r4.4xlarge', 'r4.8xlarge', 'r4.16xlarge', 'r5.large', 'r5.xlarge', 'r5.2xlarge', 'r5.4xlarge', 'r5.12xlarge', 'r5.24xlarge', 'r5d.large', 'r5d.xlarge', 'r5d.2xlarge', 'r5d.4xlarge', 'r5d.12xlarge', 'r5d.24xlarge', 'i3.large', 'i3.xlarge', 'i3.2xlarge', 'i3.4xlarge', 'i3.8xlarge', 'i3.16xlarge', 'i3en.large', 'i3en.xlarge', 'i3en.2xlarge', 'i3en.3xlarge')]
    [string]$AwsInstanceType,
    [Parameter(Mandatory)]
    [string]$AwsKeyPairName = "E2EVC-Madrid",
    [Parameter(Mandatory)]
    [string]$AwsSecurityGroupId = "mySecurityGroupId",
    [Parameter(Mandatory)]
    [string]$AwsSubnetId = "subnet-030459ac24bf1e8da"
)

#Set Error Action to Silently Continue
$ErrorActionPreference =  "Stop"


aws ec2 run-instances `
    --image-id $AwsAmiId `
    --count $AwsInstanceCount `
    --instance-type $AwsInstanceType `
    --key-name $AwsKeyPairName `
    --security-group-ids $AwsSecurityGroupId `
    --subnet-id $AwsSubnetId 
