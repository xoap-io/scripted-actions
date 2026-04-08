<#
.SYNOPSIS
    Create a snapshot of an EBS volume.

.DESCRIPTION
    This script creates a snapshot of an EBS volume using the New-EC2Snapshot cmdlet from AWS.Tools.EC2.

.PARAMETER VolumeId
    The ID of the EBS volume to snapshot.

.PARAMETER Description
    (Optional) A description for the snapshot.

.EXAMPLE
    .\aws-ps-create-snapshot.ps1 -VolumeId vol-12345678 -Description "Backup before upgrade"

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EBS volume to snapshot (e.g. vol-12345678abcdef01).")]
    [ValidatePattern('^vol-[a-zA-Z0-9]{8,}$')]
    [string]$VolumeId,

    [Parameter(HelpMessage = "An optional description for the snapshot.")]
    [string]$Description
)

$ErrorActionPreference = 'Stop'

try {
    $snap = New-EC2Snapshot -VolumeId $VolumeId -Description $Description
    Write-Host "Created snapshot: $($snap.SnapshotId) for volume $VolumeId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
