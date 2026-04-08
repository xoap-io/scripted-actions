<#
.SYNOPSIS
    List and filter EC2 instances by state, tag, or other properties.

.DESCRIPTION
    This script lists EC2 instances using the Get-EC2Instance cmdlet from AWS.Tools.EC2 and allows filtering by state, tag key, and tag value.

.PARAMETER State
    (Optional) Filter instances by state: pending, running, shutting-down, terminated, stopping, or stopped.

.PARAMETER TagKey
    (Optional) Filter instances by a specific tag key.

.PARAMETER TagValue
    (Optional) Filter instances by a specific tag value (used in conjunction with TagKey).

.EXAMPLE
    .\aws-ps-describe-instances.ps1 -State running -TagKey Name -TagValue WebServer

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
    [Parameter(HelpMessage = "Filter by instance state (pending, running, shutting-down, terminated, stopping, stopped).")]
    [ValidateSet('pending','running','shutting-down','terminated','stopping','stopped')]
    [string]$State,

    [Parameter(HelpMessage = "Filter by tag key.")]
    [string]$TagKey,

    [Parameter(HelpMessage = "Filter by tag value (used in conjunction with TagKey).")]
    [string]$TagValue
)

$ErrorActionPreference = 'Stop'

try {
    $instances = Get-EC2Instance | Select-Object -ExpandProperty Instances
    if ($State) {
        $instances = $instances | Where-Object { $_.State.Name -eq $State }
    }
    if ($TagKey) {
        $instances = $instances | Where-Object { $_.Tags | Where-Object { $_.Key -eq $TagKey -and ($TagValue ? $_.Value -eq $TagValue : $true) } }
    }
    if (-not $instances) {
        Write-Host "No EC2 instances found matching criteria." -ForegroundColor Yellow
        return
    }
    foreach ($instance in $instances) {
        $id = $instance.InstanceId
        $type = $instance.InstanceType
        $state = $instance.State.Name
        $name = ($instance.Tags | Where-Object { $_.Key -eq 'Name' }).Value
        Write-Host "Instance: $id | Type: $type | State: $state | Name: $name" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
