<#
.SYNOPSIS
    Create a new EBS volume.

.DESCRIPTION
    This script creates a new EBS volume using the New-EC2Volume cmdlet from AWS.Tools.EC2.

.PARAMETER AvailabilityZone
    The availability zone in which to create the volume (e.g. us-east-1a).

.PARAMETER Size
    The size of the volume in GiB (1–16384).

.EXAMPLE
    .\aws-ps-create-volume.ps1 -AvailabilityZone us-east-1a -Size 20

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
    [Parameter(Mandatory = $true, HelpMessage = "The availability zone for the volume (e.g. us-east-1a).")]
    [ValidatePattern('^[a-zA-Z0-9-]+$')]
    [string]$AvailabilityZone,

    [Parameter(Mandatory = $true, HelpMessage = "The size of the volume in GiB (1-16384).")]
    [ValidateRange(1, 16384)]
    [int]$Size
)

$ErrorActionPreference = 'Stop'

try {
    $vol = New-EC2Volume -AvailabilityZone $AvailabilityZone -Size $Size
    Write-Host "Created EBS volume: $($vol.VolumeId) ($Size GiB in $AvailabilityZone)" -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
