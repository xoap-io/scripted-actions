<#
.SYNOPSIS
    List tags for an AWS WorkSpace.

.DESCRIPTION
    This script retrieves and lists the tags associated with an AWS WorkSpace using the Get-WKSWorkspaceTag cmdlet from AWS.Tools.WorkSpaces.

.PARAMETER WorkspaceId
    The ID of the WorkSpace to list tags for.

.EXAMPLE
    .\aws-ps-workspaces-list-tags.ps1 -WorkspaceId ws-abc12345

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace to list tags for.")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating WorkSpace $WorkspaceId exists..." -ForegroundColor Cyan
    $workspace = Get-WKSWorkspace -WorkspaceId $WorkspaceId
    if (-not $workspace) {
        throw "WorkSpace $WorkspaceId not found"
    }

    Write-Host "Retrieving tags for WorkSpace $WorkspaceId..." -ForegroundColor Cyan

    $tags = Get-WKSWorkspaceTag -WorkspaceId $WorkspaceId

    if ($tags -and $tags.Count -gt 0) {
        Write-Host "Found $($tags.Count) tag(s) for WorkSpace ${WorkspaceId}:" -ForegroundColor Green
        $tags | Format-Table -Property Key, Value -AutoSize

        return $tags
    } else {
        Write-Host "No tags found for WorkSpace $WorkspaceId" -ForegroundColor Yellow
        return @()
    }
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
