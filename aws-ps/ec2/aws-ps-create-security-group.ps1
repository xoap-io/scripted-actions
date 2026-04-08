<#
.SYNOPSIS
    Create a new EC2 security group with rules.

.DESCRIPTION
    This script creates a new EC2 security group using the New-EC2SecurityGroup cmdlet and optionally adds inbound rules using Grant-EC2SecurityGroupIngress from AWS.Tools.EC2.

.PARAMETER GroupName
    The name of the security group to create.

.PARAMETER Description
    The description of the security group.

.PARAMETER VpcId
    The VPC ID in which to create the security group.

.PARAMETER IngressRules
    (Optional) Array of hashtables for inbound rules. Each hashtable must contain: IpProtocol, FromPort, ToPort, CidrIp.

.EXAMPLE
    .\aws-ps-create-security-group.ps1 -GroupName mySG -Description "Web SG" -VpcId vpc-12345678 -IngressRules @(@{IpProtocol="tcp";FromPort=80;ToPort=80;CidrIp="0.0.0.0/0"})

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
    [Parameter(Mandatory = $true, HelpMessage = "The name for the security group (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$GroupName,

    [Parameter(Mandatory = $true, HelpMessage = "The description for the security group.")]
    [ValidateNotNullOrEmpty()]
    [string]$Description,

    [Parameter(Mandatory = $true, HelpMessage = "The VPC ID in which to create the security group (e.g. vpc-12345678abcdef01).")]
    [ValidatePattern('^vpc-[a-zA-Z0-9]{8,}$')]
    [string]$VpcId,

    [Parameter(HelpMessage = "Optional array of hashtables for inbound rules, each with keys: IpProtocol, FromPort, ToPort, CidrIp.")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
