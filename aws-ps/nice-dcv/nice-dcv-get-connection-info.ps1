<#
.SYNOPSIS
    Output connection details for a DCV instance.

.DESCRIPTION
    This script retrieves and displays the public IP, DCV port, and user name for a NICE DCV instance using the Get-EC2Instance cmdlet from AWS.Tools.EC2.

.PARAMETER InstanceId
    The EC2 instance ID to retrieve connection info for.

.PARAMETER DcvPort
    The DCV port number (default: 8443).

.PARAMETER UserName
    The DCV user name (default: dcvuser).

.EXAMPLE
    .\nice-dcv-get-connection-info.ps1 -InstanceId i-12345678 -DcvPort 8443 -UserName dcvuser

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
    [Parameter(Mandatory = $true, HelpMessage = "The EC2 instance ID to retrieve connection info for (e.g. i-12345678abcdef01).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(HelpMessage = "The DCV port number (1024-65535, default: 8443).")]
    [ValidateRange(1024,65535)]
    [int]$DcvPort = 8443,

    [Parameter(HelpMessage = "The DCV user name (default: dcvuser).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName = 'dcvuser'
)

$ErrorActionPreference = 'Stop'

try {
    $instance = Get-EC2Instance -InstanceId $InstanceId | Select-Object -ExpandProperty Instances
    $ip = $instance[0].PublicIpAddress
    Write-Host "DCV Connection Info:" -ForegroundColor Green
    Write-Host "URL: https://${ip}:$DcvPort" -ForegroundColor Cyan
    Write-Host "User: $UserName" -ForegroundColor Cyan
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
