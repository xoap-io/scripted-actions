<#
.SYNOPSIS
    Add DCV port rules to an existing security group.

.DESCRIPTION
    This script adds DCV TCP and UDP port rules to an existing EC2 security group using the Grant-EC2SecurityGroupIngress cmdlet from AWS.Tools.EC2.

.PARAMETER SecurityGroupId
    The security group ID to add DCV port rules to.

.PARAMETER DcvPort
    The DCV port number to authorize (default: 8443).

.EXAMPLE
    .\nice-dcv-authorize-dcv-ports.ps1 -SecurityGroupId sg-12345678 -DcvPort 8443

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
    [Parameter(Mandatory = $true, HelpMessage = "The security group ID to add DCV port rules to (e.g. sg-12345678abcdef01).")]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId,

    [Parameter(HelpMessage = "The DCV port number to authorize (1024-65535, default: 8443).")]
    [ValidateRange(1024,65535)]
    [int]$DcvPort = 8443
)

$ErrorActionPreference = 'Stop'

try {
    Grant-EC2SecurityGroupIngress -GroupId $SecurityGroupId -IpProtocol 'tcp' -FromPort $DcvPort -ToPort $DcvPort -CidrIp '0.0.0.0/0'
    Grant-EC2SecurityGroupIngress -GroupId $SecurityGroupId -IpProtocol 'udp' -FromPort $DcvPort -ToPort $DcvPort -CidrIp '0.0.0.0/0'
    Write-Host "DCV ports authorized in security group $SecurityGroupId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
