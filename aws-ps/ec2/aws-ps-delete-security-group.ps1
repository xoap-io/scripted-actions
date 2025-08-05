<#
.SYNOPSIS
    Delete a security group by ID.
.DESCRIPTION
    This script deletes an EC2 security group using AWS.Tools.EC2.
.PARAMETER SecurityGroupId
    The ID of the security group to delete.
.EXAMPLE
    .\aws-ps-delete-security-group.ps1 -SecurityGroupId sg-12345678
.LINK
    https://github.com/xoap-io/scripted-actions
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^sg-[a-zA-Z0-9]{8,}$')]
    [string]$SecurityGroupId
)

$ErrorActionPreference = 'Stop'
try {
    Remove-EC2SecurityGroup -GroupId $SecurityGroupId
    Write-Host "Security group '$SecurityGroupId' deleted successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to delete security group: $_"
    exit 1
}
