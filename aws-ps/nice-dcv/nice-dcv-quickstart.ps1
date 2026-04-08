<#
.SYNOPSIS
    Quickstart for deploying NICE DCV on AWS EC2.

.DESCRIPTION
    This script launches an EC2 instance, authorizes DCV ports in a security group, and waits for the instance to be running
    using New-EC2Instance, Grant-EC2SecurityGroupIngress, and Wait-EC2InstanceRunning from AWS.Tools.EC2.

.PARAMETER AmiId
    The AMI ID for the instance (must be a supported OS for NICE DCV).

.PARAMETER InstanceType
    The EC2 instance type.

.PARAMETER KeyPairName
    The name of the key pair for SSH access.

.PARAMETER SecurityGroupId
    The security group to use (will be updated for DCV ports).

.PARAMETER SubnetId
    The subnet to launch the instance in.

.PARAMETER DcvPort
    The port for DCV connections (default: 8443).

.EXAMPLE
    .\nice-dcv-quickstart.ps1 -AmiId ami-12345678 -InstanceType g4dn.xlarge -KeyPairName myKey -SecurityGroupId sg-12345678 -SubnetId subnet-12345678 -DcvPort 8443

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
    AWS PowerShell NICE DCV
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The AMI ID for the instance (e.g. ami-12345678abcdef01).")]
    [ValidatePattern('^ami-[a-zA-Z0-9]{8,}$')]
    [string]$AmiId,

    [Parameter(Mandatory = $true, HelpMessage = "The EC2 instance type (e.g. g4dn.xlarge).")]
    [ValidateSet('g4dn.xlarge','g4dn.2xlarge','g4dn.4xlarge','g4dn.8xlarge','g4dn.12xlarge','g4dn.16xlarge','c5.large','c5.xlarge','c5.2xlarge','m5.large','m5.xlarge','m5.2xlarge')]
    [string]$InstanceType,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the key pair for SSH access.")]
    [string]$KeyPairName,

    [Parameter(Mandatory = $true, HelpMessage = "The security group ID to use and update with DCV ports (e.g. sg-12345678abcdef01).")]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,

    [Parameter(Mandatory = $true, HelpMessage = "The subnet ID to launch the instance in (e.g. subnet-12345678abcdef01).")]
    [ValidatePattern('^subnet-[a-zA-Z0-9]{8,}$')]
    [string]$SubnetId,

    [Parameter(HelpMessage = "The DCV port number (1024-65535, default: 8443).")]
    [ValidateRange(1024,65535)]
    [int]$DcvPort = 8443
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Launching EC2 instance for NICE DCV..." -ForegroundColor Cyan
    $instance = New-EC2Instance -ImageId $AmiId -InstanceType $InstanceType -KeyName $KeyPairName -SecurityGroupId $SecurityGroupId -SubnetId $SubnetId -MinCount 1 -MaxCount 1
    $instanceId = $instance.Instances[0].InstanceId
    Write-Host "Instance launched: $instanceId" -ForegroundColor Green

    Write-Host "Authorizing DCV port $DcvPort in security group $SecurityGroupId..." -ForegroundColor Cyan
    Grant-EC2SecurityGroupIngress -GroupId $SecurityGroupId -IpProtocol 'tcp' -FromPort $DcvPort -ToPort $DcvPort -CidrIp '0.0.0.0/0'
    Write-Host "DCV port authorized." -ForegroundColor Green

    Write-Host "Waiting for instance to be running..." -ForegroundColor Cyan
    Wait-EC2InstanceRunning -InstanceId $instanceId

    Write-Host "Installing NICE DCV on instance (manual step required)..." -ForegroundColor Yellow
    Write-Host "Connect via SSH and follow: https://docs.aws.amazon.com/dcv/latest/userguide/setting-up-installing-linux.html" -ForegroundColor Yellow

    Write-Host "NICE DCV quickstart completed. Instance $instanceId is ready for DCV installation." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
