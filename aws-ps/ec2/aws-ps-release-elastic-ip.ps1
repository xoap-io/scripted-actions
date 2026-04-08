<#
.SYNOPSIS
    Release an Elastic IP address.

.DESCRIPTION
    This script releases an Elastic IP address using the Remove-EC2Address cmdlet from AWS.Tools.EC2.

.PARAMETER AllocationId
    The allocation ID of the Elastic IP to release.

.EXAMPLE
    .\aws-ps-release-elastic-ip.ps1 -AllocationId eipalloc-12345678

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
    [Parameter(Mandatory = $true, HelpMessage = "The allocation ID of the Elastic IP to release (e.g. eipalloc-12345678abcdef01).")]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]{8,}$')]
    [string]$AllocationId
)

$ErrorActionPreference = 'Stop'

try {
    Remove-EC2Address -AllocationId $AllocationId
    Write-Host "Released Elastic IP ($AllocationId)." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
