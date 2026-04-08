<#
.SYNOPSIS
    Create an AMI from a configured NICE DCV Windows instance.

.DESCRIPTION
    This script creates an AMI from a Windows EC2 instance with NICE DCV installed using the New-EC2Image cmdlet from AWS.Tools.EC2.

.PARAMETER InstanceId
    The EC2 instance ID to create the AMI from.

.PARAMETER AmiName
    The name for the new AMI.

.EXAMPLE
    .\nice-dcv-create-ami-windows.ps1 -InstanceId i-12345678 -AmiName "DCV-Windows-2025"

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
    [Parameter(Mandatory = $true, HelpMessage = "The EC2 instance ID to create the AMI from (e.g. i-12345678abcdef01).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new AMI (alphanumeric, dots, dashes, up to 128 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,128}$')]
    [string]$AmiName
)

$ErrorActionPreference = 'Stop'

try {
    $ami = New-EC2Image -InstanceId $InstanceId -Name $AmiName
    Write-Host "AMI creation initiated: $($ami.ImageId) from instance $InstanceId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
