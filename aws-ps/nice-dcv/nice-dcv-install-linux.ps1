<#
.SYNOPSIS
    Remotely install and configure NICE DCV on a Linux EC2 instance via SSM.

.DESCRIPTION
    This script uses AWS Systems Manager to run the official NICE DCV installation commands on a Linux EC2 instance using the Send-SSMCommand cmdlet from AWS.Tools.SimpleSystemsManagement.

.PARAMETER InstanceId
    The EC2 instance ID to install NICE DCV on.

.EXAMPLE
    .\nice-dcv-install-linux.ps1 -InstanceId i-12345678

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
    [Parameter(Mandatory = $true, HelpMessage = "The EC2 instance ID to install NICE DCV on (e.g. i-12345678abcdef01).")]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string]$InstanceId
)

$ErrorActionPreference = 'Stop'

try {
    $commands = @(
        'sudo yum update -y',
        'curl -O https://d1uj6qtbmh3dt5.cloudfront.net/NICE-DCV-Linux-x86_64.tgz',
        'tar -xzf NICE-DCV-Linux-x86_64.tgz',
        'cd NICE-DCV-*-x86_64',
        'sudo ./install.sh'
    )
    Send-SSMCommand -InstanceId $InstanceId -Commands $commands
    Write-Host "NICE DCV installation initiated on instance $InstanceId." -ForegroundColor Green
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
