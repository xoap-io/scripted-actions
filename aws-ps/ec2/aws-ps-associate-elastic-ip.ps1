<#
.SYNOPSIS
    Associate an Elastic IP with an EC2 instance.

.DESCRIPTION
    This script associates an Elastic IP address with an EC2 instance using the Register-EC2Address cmdlet from AWS.Tools.EC2.

.PARAMETER InstanceId
    The ID of the EC2 instance to associate the Elastic IP with.

.PARAMETER AllocationId
    The allocation ID of the Elastic IP to associate.

.EXAMPLE
    .\aws-ps-associate-elastic-ip.ps1 -InstanceId i-12345678 -AllocationId eipalloc-12345678

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the EC2 instance (e.g. i-12345678abcdef01).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $true, HelpMessage = "The allocation ID of the Elastic IP (e.g. eipalloc-12345678abcdef01).")]
    [ValidatePattern('^eipalloc-[a-zA-Z0-9]{8,}$')]
    [string]$AllocationId
)

$ErrorActionPreference = 'Stop'

try {
    $assoc = Register-EC2Address -InstanceId $InstanceId -AllocationId $AllocationId
    Write-Host "Associated Elastic IP ($AllocationId) with instance $InstanceId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
