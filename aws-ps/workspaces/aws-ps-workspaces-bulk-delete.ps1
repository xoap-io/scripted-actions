[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName='CsvFile')]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CsvFilePath,
    [Parameter(Mandatory, ParameterSetName='Array')]
    [string[]]$WorkspaceIds,
    [Parameter(Mandatory, ParameterSetName='Filter')]
    [string]$DirectoryId,
    [Parameter(ParameterSetName='Filter')]
    [string]$UserNamePattern,
    [Parameter(ParameterSetName='Filter')]
    [ValidateSet('PENDING','AVAILABLE','IMPAIRED','UNHEALTHY','REBOOTING','STARTING','REBUILDING','RESTORING','MAINTENANCE','ADMIN_MAINTENANCE','TERMINATING','TERMINATED','SUSPENDED','UPDATING','STOPPING','STOPPED','ERROR')]
    [string]$State,
    [Parameter()]
    [switch]$Force,
    [Parameter()]
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
} catch {
    Write-Error "Bulk WorkSpace deletion failed: $_"
    exit 1
}
