<#
.SYNOPSIS
    List and filter EC2 instances by state, tag, or other properties.
.DESCRIPTION
    This script lists EC2 instances using AWS.Tools.EC2 and allows filtering by state, tag, or other properties.
.PARAMETER State
    (Optional) Filter by instance state (running, stopped, etc).
.PARAMETER TagKey
    (Optional) Filter by tag key.
.PARAMETER TagValue
    (Optional) Filter by tag value.
.EXAMPLE
    .\aws-ps-describe-instances.ps1 -State running -TagKey Name -TagValue WebServer
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('pending','running','shutting-down','terminated','stopping','stopped')]
    [string]$State,
    [Parameter()]
    [string]$TagKey,
    [Parameter()]
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
} catch {
    Write-Error "Failed to describe instances: $_"
    exit 1
}
