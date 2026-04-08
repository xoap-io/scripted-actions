<#
.SYNOPSIS
    Create a DCV user on an EC2 instance via SSM.

.DESCRIPTION
    This script creates a DCV user on a Linux EC2 instance by sending a useradd command via AWS Systems Manager using the Send-SSMCommand cmdlet from AWS.Tools.SimpleSystemsManagement.

.PARAMETER InstanceId
    The EC2 instance ID to create the DCV user on.

.PARAMETER UserName
    The DCV user name to create.

.EXAMPLE
    .\nice-dcv-create-user.ps1 -InstanceId i-12345678 -UserName dcvuser

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.SimpleSystemsManagement

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell NICE DCV
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The EC2 instance ID to create the DCV user on (e.g. i-12345678abcdef01).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId,

    [Parameter(Mandatory = $true, HelpMessage = "The DCV user name to create (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName
)

$ErrorActionPreference = 'Stop'

try {
    $commands = @("sudo useradd $UserName")
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "DCV user $UserName creation command sent to instance $InstanceId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
