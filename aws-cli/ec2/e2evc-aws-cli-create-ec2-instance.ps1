<#
.SYNOPSIS
    Creates an EC2 instance in AWS using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script robustly creates an EC2 instance, with improved error handling, parameter validation,
    and output. It checks for AWS CLI presence and provides clear feedback.
    Uses aws ec2 run-instances to launch the instance.
    Compatible with AWS CLI v2.16+ (2025).

.PARAMETER AmiId
    The ID of the Amazon Machine Image (AMI).

.PARAMETER InstanceCount
    The number of instances to launch.

.PARAMETER InstanceType
    The type of instance to launch.

.PARAMETER KeyPairName
    The name of the key pair.

.PARAMETER SecurityGroupId
    The ID of the security group.

.PARAMETER SubnetId
    The ID of the subnet.

.EXAMPLE
    .\e2evc-aws-cli-create-ec2-instance.ps1 -AmiId ami-12345678 -InstanceCount 1 -InstanceType t3.micro -KeyPairName myKey -SecurityGroupId sg-12345678 -SubnetId subnet-12345678

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
    https://docs.aws.amazon.com/cli/latest/reference/ec2/run-instances.html

.COMPONENT
    AWS CLI EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the Amazon Machine Image (AMI).")]
    [ValidatePattern('^ami-[a-zA-Z0-9]{8,}$')]
    [string]$AmiId,

    [Parameter(Mandatory = $true, HelpMessage = "The number of instances to launch.")]
    [int]$InstanceCount = 1,

    [Parameter(Mandatory = $true, HelpMessage = "The type of instance to launch.")]
    [ValidateSet('t2.micro','t2.small','t2.medium','t3.micro','t3.small','t3.medium','t3.large','m5.large','m5.xlarge','m5.2xlarge','m5.4xlarge','c5.large','c5.xlarge','c5.2xlarge','c5.4xlarge','r5.large','r5.xlarge','r5.2xlarge','r5.4xlarge','c6g.medium','c6g.large','c6g.xlarge','c6g.2xlarge','c6g.4xlarge','m6i.large','m6i.xlarge','m6i.2xlarge','m6i.4xlarge','r6i.large','r6i.xlarge','r6i.2xlarge','r6i.4xlarge')]
    [string]$InstanceType,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the key pair.")]
    [ValidatePattern('^[a-zA-Z0-9-_]{1,255}$')]
    [string]$KeyPairName,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the security group.")]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the subnet.")]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "❌ AWS CLI is not installed or not in PATH." -ForegroundColor Red
    exit 127
}

try {
    $result = aws ec2 run-instances `
        --image-id $AmiId `
        --count $InstanceCount `
        --instance-type $InstanceType `
        --key-name $KeyPairName `
        --security-group-ids $SecurityGroupId `
        --subnet-id $SubnetId `
        --output json 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ EC2 instance(s) created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        throw "Failed to create EC2 instance(s): $result"
    }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
