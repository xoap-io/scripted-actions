<#
.SYNOPSIS
    Delete an EBS volume.

.DESCRIPTION
    This script deletes an EBS volume using the Remove-EC2Volume cmdlet from AWS.Tools.EC2.

.PARAMETER VolumeId
    The ID of the EBS volume to delete.

.EXAMPLE
    .\aws-ps-delete-volume.ps1 -VolumeId vol-12345678

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EBS volume to delete (e.g. vol-12345678abcdef01).")]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId
)

$ErrorActionPreference = 'Stop'

try {
    Remove-EC2Volume -VolumeId $VolumeId -Force
    Write-Host "Deleted EBS volume $VolumeId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
