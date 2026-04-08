<#
.SYNOPSIS
    Remove tags from one or more AWS WorkSpaces.

.DESCRIPTION
    This script removes tags from AWS WorkSpaces using the Remove-WKSWorkspaceTag cmdlet from AWS.Tools.WorkSpaces.
    Skips WorkSpaces that are not found.

.PARAMETER WorkspaceId
    Array of WorkSpace IDs to remove tags from.

.PARAMETER TagKeys
    Array of tag keys to remove from the WorkSpaces.

.EXAMPLE
    .\aws-ps-workspaces-untag-workspace.ps1 -WorkspaceId ws-abc12345 -TagKeys Environment,Owner

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
    [Parameter(Mandatory = $true, HelpMessage = "Array of WorkSpace IDs to remove tags from.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "Array of tag keys to remove from the WorkSpaces.")]
    [string[]]$TagKeys
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

        Write-Host "Removing tags from WorkSpace $id..." -ForegroundColor Cyan

        Remove-WKSWorkspaceTag -WorkspaceId $id -TagKeys $TagKeys

        Write-Host "Tags removed successfully from WorkSpace ${id}:" -ForegroundColor Green
        foreach ($key in $TagKeys) {
            Write-Host "  $key" -ForegroundColor White
        }
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
