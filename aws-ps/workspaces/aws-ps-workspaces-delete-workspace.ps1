<#
.SYNOPSIS
    Delete one or more AWS WorkSpaces.

.DESCRIPTION
    This script terminates one or more AWS WorkSpaces using the Remove-WKSWorkspace and Get-WKSWorkspace cmdlets from AWS.Tools.WorkSpaces.
    Skips WorkSpaces that are already terminated or terminating.

.PARAMETER WorkspaceId
    Array of WorkSpace IDs to delete.

.PARAMETER Force
    Switch to skip confirmation prompts.

.EXAMPLE
    .\aws-ps-workspaces-delete-workspace.ps1 -WorkspaceId ws-abc12345 -Force

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.WorkSpaces

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Array of WorkSpace IDs to delete.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId,

    [Parameter(HelpMessage = "Switch to skip confirmation prompts.")]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    foreach ($id in $WorkspaceId) {
        Write-Host "Validating WorkSpace $id exists..." -ForegroundColor Cyan
        $workspace = Get-WKSWorkspace -WorkspaceId $id
        if (-not $workspace) {
            Write-Warning "WorkSpace $id not found, skipping"
            continue
        }

        if ($workspace.State -eq 'TERMINATING' -or $workspace.State -eq 'TERMINATED') {
            Write-Warning "WorkSpace $id is already terminated or terminating, skipping"
            continue
        }

        if (-not $Force) {
            $confirmation = Read-Host "Are you sure you want to delete WorkSpace $id for user $($workspace.UserName)? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Host "Skipping WorkSpace $id" -ForegroundColor Yellow
                continue
            }
        }

        Write-Host "Terminating WorkSpace $id..." -ForegroundColor Cyan
        Remove-WKSWorkspace -WorkspaceId $id
        Write-Host "WorkSpace $id termination initiated successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
