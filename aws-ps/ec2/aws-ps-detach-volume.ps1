<#
.SYNOPSIS
    Detach an EBS volume from an EC2 instance.

.DESCRIPTION
    This script detaches an EBS volume from an EC2 instance using the Unregister-EC2Volume cmdlet from AWS.Tools.EC2.

.PARAMETER VolumeId
    The ID of the EBS volume to detach.

.EXAMPLE
    .\aws-ps-detach-volume.ps1 -VolumeId vol-12345678

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EBS volume to detach (e.g. vol-12345678abcdef01).")]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId
)

$ErrorActionPreference = 'Stop'

try {
    Unregister-EC2Volume -VolumeId $VolumeId
    Write-Host "Detached volume $VolumeId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
