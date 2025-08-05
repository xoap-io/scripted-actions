<#
.SYNOPSIS
    Create a security group with recommended DCV ports.
.DESCRIPTION
    This script creates a security group and adds rules for DCV TCP/UDP ports.
.PARAMETER GroupName
    The name of the security group.
.PARAMETER Description
    The description of the security group.
.PARAMETER VpcId
    The VPC ID for the security group.
.EXAMPLE
    .\nice-dcv-create-security-group.ps1 -GroupName DCVGroup -Description "NICE DCV SG" -VpcId vpc-12345678
.LINK
    https://docs.aws.amazon.com/dcv/latest/userguide/setting-up-installing-linux.html
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$GroupName,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Description,
    [Parameter(Mandatory)]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId
)

$ErrorActionPreference = 'Stop'
try {
    $sg = New-EC2SecurityGroup -GroupName $GroupName -Description $Description -VpcId $VpcId
    Grant-EC2SecurityGroupIngress -GroupId $sg.GroupId -IpProtocol 'tcp' -FromPort 8443 -ToPort 8443 -CidrIp '0.0.0.0/0'
    Grant-EC2SecurityGroupIngress -GroupId $sg.GroupId -IpProtocol 'udp' -FromPort 8443 -ToPort 8443 -CidrIp '0.0.0.0/0'
    Write-Host "Security group '$GroupName' created and DCV ports authorized: $($sg.GroupId)" -ForegroundColor Green
} catch {
    Write-Error "Failed to create DCV security group: $_"
    exit 1
}
