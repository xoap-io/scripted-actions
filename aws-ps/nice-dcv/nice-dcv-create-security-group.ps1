<#
.SYNOPSIS
    Create a security group with recommended DCV ports.

.DESCRIPTION
    This script creates an EC2 security group and adds DCV TCP and UDP port 8443 rules using New-EC2SecurityGroup and Grant-EC2SecurityGroupIngress from AWS.Tools.EC2.

.PARAMETER GroupName
    The name of the security group to create.

.PARAMETER Description
    The description of the security group.

.PARAMETER VpcId
    The VPC ID in which to create the security group.

.EXAMPLE
    .\nice-dcv-create-security-group.ps1 -GroupName DCVGroup -Description "NICE DCV SG" -VpcId vpc-12345678

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
    [Parameter(Mandatory = $true, HelpMessage = "The name for the security group (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$GroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The description for the security group.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory = $true, HelpMessage = "The VPC ID in which to create the security group (e.g. vpc-12345678abcdef01).")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId
)

$ErrorActionPreference = 'Stop'

try {
    $sg = New-EC2SecurityGroup -GroupName $GroupName -Description $Description -VpcId $VpcId
    Grant-EC2SecurityGroupIngress -GroupId $sg.GroupId -IpProtocol 'tcp' -FromPort 8443 -ToPort 8443 -CidrIp '0.0.0.0/0'
    Grant-EC2SecurityGroupIngress -GroupId $sg.GroupId -IpProtocol 'udp' -FromPort 8443 -ToPort 8443 -CidrIp '0.0.0.0/0'
    Write-Host "Security group '$GroupName' created and DCV ports authorized: $($sg.GroupId)" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
