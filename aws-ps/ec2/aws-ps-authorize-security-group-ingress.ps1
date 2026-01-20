<#
.SYNOPSIS
    Add inbound rules to a security group.
.DESCRIPTION
    This script adds inbound rules to an EC2 security group using AWS.Tools.EC2.
.PARAMETER SecurityGroupId
    The ID of the security group.
.PARAMETER IngressRules
    Array of hashtables for inbound rules (IpProtocol, FromPort, ToPort, CidrIp).
.EXAMPLE
    .\aws-ps-authorize-security-group-ingress.ps1 -SecurityGroupId sg-12345678 -IngressRules @(@{IpProtocol="tcp";FromPort=22;ToPort=22;CidrIp="0.0.0.0/0"})
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,
    [Parameter(Mandatory)]
    [hashtable[]]$IngressRules
)

$ErrorActionPreference = 'Stop'
try {
    foreach ($rule in $IngressRules) {
        Grant-EC2SecurityGroupIngress -GroupId $SecurityGroupId -IpProtocol $rule.IpProtocol -FromPort $rule.FromPort -ToPort $rule.ToPort -CidrIp $rule.CidrIp
        Write-Host "Added ingress rule: $($rule.IpProtocol) $($rule.FromPort)-$($rule.ToPort) $($rule.CidrIp)" -ForegroundColor Cyan
    }
    Write-Host "Ingress rules added to security group '$SecurityGroupId'." -ForegroundColor Green
} catch {
    Write-Error "Failed to add ingress rules: $_"
    exit 1
}
