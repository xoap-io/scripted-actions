<#
.SYNOPSIS
    Add tags to one or more AWS WorkSpaces.

.DESCRIPTION
    This script adds tags to AWS WorkSpaces using the New-WKSWorkspaceTag cmdlet from AWS.Tools.WorkSpaces.
    Skips WorkSpaces that are not found.

.PARAMETER WorkspaceId
    Array of WorkSpace IDs to add tags to.

.PARAMETER Tags
    Hashtable of tags to apply to the WorkSpaces (Key-Value pairs).

.EXAMPLE
    .\aws-ps-workspaces-tag-workspace.ps1 -WorkspaceId ws-abc12345 -Tags @{Environment='Production';Owner='TeamA'}

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
    [Parameter(Mandatory = $true, HelpMessage = "Array of WorkSpace IDs to add tags to.")]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "Hashtable of tags to apply (Key-Value pairs).")]
    [hashtable]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    if ($Tags.Count -eq 0) {
        Write-Warning "No tags specified"
        exit 0
    }

    foreach ($id in $WorkspaceId) {
        Write-Host "Validating WorkSpace $id exists..." -ForegroundColor Cyan
        $workspace = Get-WKSWorkspace -WorkspaceId $id
        if (-not $workspace) {
            Write-Warning "WorkSpace $id not found, skipping"
            continue
        }

        Write-Host "Adding tags to WorkSpace $id..." -ForegroundColor Cyan

        $tagList = $Tags.GetEnumerator() | ForEach-Object { @{Key=$_.Key; Value=$_.Value} }

        New-WKSWorkspaceTag -WorkspaceId $id -Tags $tagList

        Write-Host "Tags added successfully to WorkSpace ${id}:" -ForegroundColor Green
        foreach ($tag in $Tags.GetEnumerator()) {
            Write-Host "  $($tag.Key): $($tag.Value)" -ForegroundColor White
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
