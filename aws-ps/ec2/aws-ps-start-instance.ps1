<#
.SYNOPSIS
    Start one or more EC2 instances.

.DESCRIPTION
    This script starts EC2 instances using the Start-EC2Instance cmdlet from AWS.Tools.EC2.

.PARAMETER InstanceIds
    Array of EC2 instance IDs to start.

.EXAMPLE
    .\aws-ps-start-instance.ps1 -InstanceIds i-12345678,i-87654321

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
    [Parameter(Mandatory = $true, HelpMessage = "Array of EC2 instance IDs to start (e.g. i-12345678abcdef01).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string[]]$InstanceIds
)

$ErrorActionPreference = 'Stop'

try {
    foreach ($id in $InstanceIds) {
        Start-EC2Instance -InstanceId $id
        Write-Host "Started instance: $id" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
