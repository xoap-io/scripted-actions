
<#!
.SYNOPSIS
    Reboots an AWS WorkSpace using AWS.Tools.WorkSpaces (2025).

.DESCRIPTION
    This script reboots an AWS WorkSpace using the latest AWS PowerShell module. It validates parameters and provides robust error handling.

.PARAMETER WorkspaceId
    The ID of the WorkSpace to reboot.

.EXAMPLE
    .\aws-ps-reboot-workspace.ps1 -WorkspaceId ws-abc12345

.LINK
    https://github.com/xoap-io/scripted-actions
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$WorkspaceId
)

$ErrorActionPreference = 'Stop'

try {
    $result = Restart-WKSWorkspace -WorkspaceId $WorkspaceId 2>&1
    if ($?) {
        Write-Host "WorkSpace '$WorkspaceId' rebooted successfully." -ForegroundColor Green
        Write-Host $result
    } else {
        Write-Error "Failed to reboot WorkSpace '$WorkspaceId': $result"
        exit 1
    }
} catch {
    Write-Error "Unexpected error: $_"
    exit 1
}
