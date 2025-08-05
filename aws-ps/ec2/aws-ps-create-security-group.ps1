<#
.SYNOPSIS
    Create a new EC2 security group with rules.
.DESCRIPTION
    This script creates a new EC2 security group and optionally adds inbound rules.
.PARAMETER GroupName
    The name of the security group.
.PARAMETER Description
    The description of the security group.
.PARAMETER VpcId
    The VPC ID for the security group.
.PARAMETER IngressRules
    (Optional) Array of hashtables for inbound rules (IpProtocol, FromPort, ToPort, CidrIp).
.EXAMPLE
    .\aws-ps-create-security-group.ps1 -GroupName mySG -Description "Web SG" -VpcId vpc-12345678 -IngressRules @(@{IpProtocol="tcp";FromPort=80;ToPort=80;CidrIp="0.0.0.0/0"})
.LINK
    https://github.com/xoap-io/scripted-actions
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
    [string]$VpcId,
    [Parameter()]
    [hashtable[]]$IngressRules
)

$ErrorActionPreference = 'Stop'
try {
    $sg = New-EC2SecurityGroup -GroupName $GroupName -Description $Description -VpcId $VpcId
    Write-Host "Security group '$GroupName' created: $($sg.GroupId)" -ForegroundColor Green
    if ($IngressRules) {
        foreach ($rule in $IngressRules) {
            Grant-EC2SecurityGroupIngress -GroupId $sg.GroupId -IpProtocol $rule.IpProtocol -FromPort $rule.FromPort -ToPort $rule.ToPort -CidrIp $rule.CidrIp
            Write-Host "Added ingress rule: $($rule.IpProtocol) $($rule.FromPort)-$($rule.ToPort) $($rule.CidrIp)" -ForegroundColor Cyan
        }
    }
} catch {
    Write-Error "Failed to create security group: $_"
    exit 1
}
