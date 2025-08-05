
<#!
.SYNOPSIS
    Creates an EC2 instance in AWS using the latest AWS CLI (v2.16+).

.DESCRIPTION
    This script robustly creates an EC2 instance, with improved error handling, parameter validation, and output. It checks for AWS CLI presence and provides clear feedback. Compatible with AWS CLI v2.16+ (2025).

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

.LINK
    https://github.com/xoap-io/scripted-actions
#>


[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ami-[a-zA-Z0-9]{8,}$')]
    [string]$AmiId,
    [Parameter(Mandatory)]
    [int]$InstanceCount = 1,
    [Parameter(Mandatory)]
    [ValidateSet('t2.micro','t2.small','t2.medium','t3.micro','t3.small','t3.medium','t3.large','m5.large','m5.xlarge','m5.2xlarge','m5.4xlarge','c5.large','c5.xlarge','c5.2xlarge','c5.4xlarge','r5.large','r5.xlarge','r5.2xlarge','r5.4xlarge','c6g.medium','c6g.large','c6g.xlarge','c6g.2xlarge','c6g.4xlarge','m6i.large','m6i.xlarge','m6i.2xlarge','m6i.4xlarge','r6i.large','r6i.xlarge','r6i.2xlarge','r6i.4xlarge')]
    [string]$InstanceType,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9-_]{1,255}$')]
    [string]$KeyPairName,
    [Parameter(Mandatory)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,
    [Parameter(Mandatory)]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId
)

$ErrorActionPreference = 'Stop'

# Check for AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
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
        Write-Host "EC2 instance(s) created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to create EC2 instance(s): $result"
        exit $LASTEXITCODE
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}

