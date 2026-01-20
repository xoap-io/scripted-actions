<#
.SYNOPSIS
    Stop one or more EC2 instances.
.DESCRIPTION
    This script stops EC2 instances using AWS.Tools.EC2.
.PARAMETER InstanceIds
    Array of EC2 instance IDs to stop.
.EXAMPLE
    .\aws-ps-stop-instance.ps1 -InstanceIds i-12345678,i-87654321
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^i-[a-zA-Z0-9]{8,}$')]
    [string[]]$InstanceIds
)

$ErrorActionPreference = 'Stop'
try {
    foreach ($id in $InstanceIds) {
        Stop-EC2Instance -InstanceId $id
        Write-Host "Stopped instance: $id" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to stop instance(s): $_"
    exit 1
}
