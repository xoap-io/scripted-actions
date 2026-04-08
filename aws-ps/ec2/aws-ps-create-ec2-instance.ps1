<#
.SYNOPSIS
    Creates an EC2 instance in AWS using AWS.Tools.EC2.

.DESCRIPTION
    This script creates an EC2 instance using the New-EC2Instance cmdlet from AWS.Tools.EC2. It validates parameters and provides robust error handling.

.PARAMETER AmiId
    The ID of the Amazon Machine Image (AMI) to use for the instance.

.PARAMETER InstanceCount
    The number of instances to launch.

.PARAMETER InstanceType
    The type of instance to launch (e.g. t3.micro, m5.large).

.PARAMETER KeyPairName
    The name of the key pair to use for SSH access.

.PARAMETER SecurityGroupId
    The ID of the security group to associate with the instance.

.PARAMETER SubnetId
    The ID of the subnet to launch the instance in.

.EXAMPLE
    .\aws-ps-create-ec2-instance.ps1 -AmiId ami-12345678 -InstanceCount 1 -InstanceType t3.micro -KeyPairName myKey -SecurityGroupId sg-12345678 -SubnetId subnet-12345678

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.EC2

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell EC2
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the Amazon Machine Image (e.g. ami-12345678abcdef01).")]
    [ValidatePattern('^ami-[a-zA-Z0-9]{8,}$')]
    [string]$AmiId,

    [Parameter(Mandatory = $true, HelpMessage = "The number of instances to launch (1-100).")]
    [ValidateRange(1, 100)]
    [int]$InstanceCount,

    [Parameter(Mandatory = $true, HelpMessage = "The EC2 instance type (e.g. t3.micro, m5.large).")]
    [ValidateSet('t2.micro','t2.small','t2.medium','t3.micro','t3.small','t3.medium','t3.large','m5.large','m5.xlarge','m5.2xlarge','m5.4xlarge','c5.large','c5.xlarge','c5.2xlarge','c5.4xlarge','r5.large','r5.xlarge','r5.2xlarge','r5.4xlarge','c6g.medium','c6g.large','c6g.xlarge','c6g.2xlarge','c6g.4xlarge','m6i.large','m6i.xlarge','m6i.2xlarge','m6i.4xlarge','r6i.large','r6i.xlarge','r6i.2xlarge','r6i.4xlarge')]
    [string]$InstanceType,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the EC2 key pair for SSH access.")]
    [string]$KeyPairName,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the security group to associate with the instance (e.g. sg-12345678abcdef01).")]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the subnet to launch the instance in (e.g. subnet-12345678abcdef01).")]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId
)

$ErrorActionPreference = 'Stop'

try {
    $result = New-EC2Instance -ImageId $AmiId -InstanceType $InstanceType -KeyName $KeyPairName -SecurityGroupId $SecurityGroupId -SubnetId $SubnetId -MinCount $InstanceCount -MaxCount $InstanceCount 2>&1
    if ($?) {
        Write-Host "EC2 instance(s) created successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Host "❌ Failed to create EC2 instance(s): $result" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
