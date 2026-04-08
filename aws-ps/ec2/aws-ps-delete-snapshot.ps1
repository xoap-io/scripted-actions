<#
.SYNOPSIS
    Delete a snapshot.

.DESCRIPTION
    This script deletes an EBS snapshot using the Remove-EC2Snapshot cmdlet from AWS.Tools.EC2.

.PARAMETER SnapshotId
    The ID of the snapshot to delete.

.EXAMPLE
    .\aws-ps-delete-snapshot.ps1 -SnapshotId snap-12345678

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the snapshot to delete (e.g. snap-12345678abcdef01).")]
    [ValidatePattern('^snap-[a-zA-Z0-9]{8,}$')]
    [string]$SnapshotId
)

$ErrorActionPreference = 'Stop'

try {
    Remove-EC2Snapshot -SnapshotId $SnapshotId -Force
    Write-Host "Deleted snapshot $SnapshotId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
