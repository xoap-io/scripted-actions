<#
.SYNOPSIS
    Add inbound rules to a security group.

.DESCRIPTION
    This script adds inbound rules to an EC2 security group using the Grant-EC2SecurityGroupIngress cmdlet from AWS.Tools.EC2.

.PARAMETER SecurityGroupId
    The ID of the security group to add ingress rules to.

.PARAMETER IngressRules
    Array of hashtables defining inbound rules. Each hashtable must contain: IpProtocol, FromPort, ToPort, CidrIp.

.EXAMPLE
    .\aws-ps-authorize-security-group-ingress.ps1 -SecurityGroupId sg-12345678 -IngressRules @(@{IpProtocol="tcp";FromPort=22;ToPort=22;CidrIp="0.0.0.0/0"})

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the security group (e.g. sg-12345678abcdef01).")]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,

    [Parameter(Mandatory = $true, HelpMessage = "Array of hashtables for inbound rules, each with keys: IpProtocol, FromPort, ToPort, CidrIp.")]
    [hashtable[]]$IngressRules
)

$ErrorActionPreference = 'Stop'

try {
    foreach ($rule in $IngressRules) {
        Grant-EC2SecurityGroupIngress -GroupId $SecurityGroupId -IpProtocol $rule.IpProtocol -FromPort $rule.FromPort -ToPort $rule.ToPort -CidrIp $rule.CidrIp
        Write-Host "Added ingress rule: $($rule.IpProtocol) $($rule.FromPort)-$($rule.ToPort) $($rule.CidrIp)" -ForegroundColor Cyan
    }
    Write-Host "Ingress rules added to security group '$SecurityGroupId'." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
