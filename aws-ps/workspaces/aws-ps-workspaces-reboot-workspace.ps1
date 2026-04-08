<#
.SYNOPSIS
    Reboot one or more AWS WorkSpaces.

.DESCRIPTION
    This script reboots AWS WorkSpaces using the Restart-WKSWorkspace cmdlet from AWS.Tools.WorkSpaces.
    Skips WorkSpaces that are not in a rebootable state.

.PARAMETER WorkspaceId
    Array of WorkSpace IDs to reboot.

.EXAMPLE
    .\aws-ps-workspaces-reboot-workspace.ps1 -WorkspaceId ws-abc12345,ws-def67890

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
    [Parameter(Mandatory = $true, HelpMessage = "Array of WorkSpace IDs to reboot.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId
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

        if ($workspace.State -ne 'AVAILABLE' -and $workspace.State -ne 'STOPPED') {
            Write-Warning "WorkSpace $id is in state '$($workspace.State)' and cannot be rebooted, skipping"
            continue
        }

        Write-Host "Rebooting WorkSpace $id..." -ForegroundColor Cyan
        Restart-WKSWorkspace -WorkspaceId $id
        Write-Host "WorkSpace $id reboot initiated successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
