<#
.SYNOPSIS
    Add outbound rules to a security group.
.DESCRIPTION
    This script adds outbound rules to an EC2 security group using AWS.Tools.EC2.
.PARAMETER SecurityGroupId
    The ID of the security group.
.PARAMETER EgressRules
    Array of hashtables for outbound rules (IpProtocol, FromPort, ToPort, CidrIp).
.EXAMPLE
    .\aws-ps-authorize-security-group-egress.ps1 -SecurityGroupId sg-12345678 -EgressRules @(@{IpProtocol="tcp";FromPort=443;ToPort=443;CidrIp="0.0.0.0/0"})
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,
    [Parameter(Mandatory)]
    [hashtable[]]$EgressRules
)

$ErrorActionPreference = 'Stop'
try {
    foreach ($rule in $EgressRules) {
        Grant-EC2SecurityGroupEgress -GroupId $SecurityGroupId -IpProtocol $rule.IpProtocol -FromPort $rule.FromPort -ToPort $rule.ToPort -CidrIp $rule.CidrIp
        Write-Host "Added egress rule: $($rule.IpProtocol) $($rule.FromPort)-$($rule.ToPort) $($rule.CidrIp)" -ForegroundColor Cyan
    }
    Write-Host "Egress rules added to security group '$SecurityGroupId'." -ForegroundColor Green
} catch {
    Write-Error "Failed to add egress rules: $_"
    exit 1
}
