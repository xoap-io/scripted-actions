<#
.SYNOPSIS
    Bulk delete AWS WorkSpaces by CSV, ID list, or filter criteria.

.DESCRIPTION
    This script terminates multiple AWS WorkSpaces in bulk using the Remove-WKSWorkspace and Get-WKSWorkspace cmdlets from AWS.Tools.WorkSpaces.
    Input can be provided as a CSV file, an array of WorkSpace IDs, or filter criteria (DirectoryId, UserNamePattern, State).

.PARAMETER CsvFilePath
    Path to a CSV file containing WorkSpace IDs to delete (column: WorkspaceId).

.PARAMETER WorkspaceIds
    Array of WorkSpace IDs to delete.

.PARAMETER DirectoryId
    Directory ID to filter WorkSpaces for deletion.

.PARAMETER UserNamePattern
    Wildcard pattern to filter WorkSpaces by user name.

.PARAMETER State
    Filter WorkSpaces by state before deletion.

.PARAMETER Force
    Switch to skip confirmation prompts.

.PARAMETER WhatIf
    Switch to preview which WorkSpaces would be deleted without actually deleting them.

.EXAMPLE
    .\aws-ps-workspaces-bulk-delete.ps1 -CsvFilePath ./workspaces-to-delete.csv

.EXAMPLE
    .\aws-ps-workspaces-bulk-delete.ps1 -WorkspaceIds ws-abc12345,ws-def67890 -Force

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
    [Parameter(Mandatory = $true, ParameterSetName = 'CsvFile', HelpMessage = "Path to the CSV file containing WorkSpace IDs to delete (column: WorkspaceId).")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CsvFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'Array', HelpMessage = "Array of WorkSpace IDs to delete.")]
    [string[]]$WorkspaceIds,

    [Parameter(Mandatory = $true, ParameterSetName = 'Filter', HelpMessage = "Directory ID to filter WorkSpaces for deletion.")]
    [string]$DirectoryId,

    [Parameter(ParameterSetName = 'Filter', HelpMessage = "Wildcard pattern to filter WorkSpaces by user name.")]
    [string]$UserNamePattern,

    [Parameter(ParameterSetName = 'Filter', HelpMessage = "Filter WorkSpaces by state before deletion.")]
    [ValidateSet('PENDING','AVAILABLE','IMPAIRED','UNHEALTHY','REBOOTING','STARTING','REBUILDING','RESTORING','MAINTENANCE','ADMIN_MAINTENANCE','TERMINATING','TERMINATED','SUSPENDED','UPDATING','STOPPING','STOPPED','ERROR')]
    [string]$State,

    [Parameter(HelpMessage = "Switch to skip confirmation prompts.")]
    [switch]$Force,

    [Parameter(HelpMessage = "Switch to preview which WorkSpaces would be deleted without actually deleting them.")]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

try {
    $workspacesToDelete = @()

    if ($CsvFilePath) {
        Write-Host "Reading WorkSpace IDs from CSV file: $CsvFilePath" -ForegroundColor Cyan
        $csvData = Import-Csv -Path $CsvFilePath
        $workspacesToDelete = $csvData | ForEach-Object { $_.WorkspaceId }
    } elseif ($WorkspaceIds) {
        $workspacesToDelete = $WorkspaceIds
    } else {
        # Filter-based selection
        Write-Host "Finding WorkSpaces matching criteria..." -ForegroundColor Cyan
        $params = @{}
        if ($DirectoryId) { $params['DirectoryId'] = $DirectoryId }

        $workspaces = Get-WKSWorkspace @params

        if ($UserNamePattern) {
            $workspaces = $workspaces | Where-Object { $_.UserName -like $UserNamePattern }
        }

        if ($State) {
            $workspaces = $workspaces | Where-Object { $_.State -eq $State }
        }

        $workspacesToDelete = $workspaces | ForEach-Object { $_.WorkspaceId }
    }

    if ($workspacesToDelete.Count -eq 0) {
        Write-Warning "No WorkSpaces found to delete"
        exit 0
    }

    Write-Host "Found $($workspacesToDelete.Count) WorkSpace(s) for deletion" -ForegroundColor Cyan

    # Show what will be deleted
    foreach ($id in $workspacesToDelete) {
        $workspace = Get-WKSWorkspace -WorkspaceId $id
        if ($workspace) {
            Write-Host "  $id - User: $($workspace.UserName), State: $($workspace.State)" -ForegroundColor Yellow
        }
    }

    if ($WhatIf) {
        Write-Host "WhatIf mode - no WorkSpaces will be deleted" -ForegroundColor Yellow
        exit 0
    }

    if (-not $Force) {
        Write-Host ""
        $confirmation = Read-Host "Are you sure you want to delete these $($workspacesToDelete.Count) WorkSpace(s)? This action cannot be undone! (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Host "Bulk deletion cancelled" -ForegroundColor Yellow
            exit 0
        }
    }

    $successful = 0
    $failed = 0
    $results = @()

    foreach ($id in $workspacesToDelete) {
        try {
            Write-Host "Deleting WorkSpace $id..." -ForegroundColor Cyan

            $workspace = Get-WKSWorkspace -WorkspaceId $id
            if (-not $workspace) {
                throw "WorkSpace not found"
            }

            if ($workspace.State -eq 'TERMINATING' -or $workspace.State -eq 'TERMINATED') {
                $results += @{
                    WorkspaceId = $id
                    UserName = $workspace.UserName
                    Status = 'Skipped'
                    Message = 'Already terminated or terminating'
                }
                Write-Host "  ⚠ Skipping $id - already terminated or terminating" -ForegroundColor Yellow
                continue
            }

            Remove-WKSWorkspace -WorkspaceId $id

            $results += @{
                WorkspaceId = $id
                UserName = $workspace.UserName
                Status = 'Success'
                Message = 'Termination initiated'
            }

            Write-Host "  ✓ Termination initiated for WorkSpace $id (User: $($workspace.UserName))" -ForegroundColor Green
            $successful++

        } catch {
            $results += @{
                WorkspaceId = $id
                UserName = 'Unknown'
                Status = 'Failed'
                Message = $_.Exception.Message
            }

            Write-Host "  ✗ Failed to delete WorkSpace ${id}: $_" -ForegroundColor Red
            $failed++
        }
    }

    Write-Host ""
    Write-Host "Bulk deletion summary:" -ForegroundColor Cyan
    Write-Host "  Successful: $successful" -ForegroundColor Green
    Write-Host "  Failed: $failed" -ForegroundColor Red
    Write-Host "  Total: $($workspacesToDelete.Count)" -ForegroundColor White

    # Display results table
    $results | ForEach-Object { [PSCustomObject]$_ } | Format-Table -AutoSize

    return $results
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
