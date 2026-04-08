<#
.SYNOPSIS
    Get connection status for one or more AWS WorkSpaces.

.DESCRIPTION
    This script retrieves connection status information for AWS WorkSpaces using the Get-WKSWorkspaceConnectionStatus cmdlet from AWS.Tools.WorkSpaces.

.PARAMETER WorkspaceId
    Array of WorkSpace IDs to retrieve connection status for.

.EXAMPLE
    .\aws-ps-workspaces-get-workspace-connection-status.ps1 -WorkspaceId ws-abc12345,ws-def67890

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
    [Parameter(Mandatory = $true, HelpMessage = "Array of WorkSpace IDs to retrieve connection status for.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId
)

$ErrorActionPreference = 'Stop'

try {
    foreach ($id in $WorkspaceId) {
        Write-Host "Retrieving connection status for WorkSpace $id..." -ForegroundColor Cyan

        $workspace = Get-WKSWorkspace -WorkspaceId $id
        if (-not $workspace) {
            Write-Warning "WorkSpace $id not found, skipping"
            continue
        }

        $connectionStatus = Get-WKSWorkspaceConnectionStatus -WorkspaceId $id

        if ($connectionStatus) {
            Write-Host "Connection Status for WorkSpace ${id}:" -ForegroundColor Green
            Write-Host "  WorkSpace ID: $($connectionStatus.WorkspaceId)" -ForegroundColor White
            Write-Host "  Connection State: $($connectionStatus.ConnectionState)" -ForegroundColor White
            Write-Host "  Connection State Check Timestamp: $($connectionStatus.ConnectionStateCheckTimestamp)" -ForegroundColor White
            Write-Host "  Last Known User Connection Timestamp: $($connectionStatus.LastKnownUserConnectionTimestamp)" -ForegroundColor White
        } else {
            Write-Warning "No connection status available for WorkSpace $id"
        }
        Write-Host ""
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
