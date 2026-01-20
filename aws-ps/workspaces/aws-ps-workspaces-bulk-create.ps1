[CmdletBinding()]
param(
    [Parameter(Mandatory, ParameterSetName='CsvFile')]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CsvFilePath,
    [Parameter(Mandatory, ParameterSetName='Array')]
    [hashtable[]]$WorkspaceData,
    [Parameter()]
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

try {
    $workspacesToCreate = @()

    if ($CsvFilePath) {
        Write-Host "Reading WorkSpace data from CSV file: $CsvFilePath" -ForegroundColor Cyan
        $csvData = Import-Csv -Path $CsvFilePath

        foreach ($row in $csvData) {
            $workspacesToCreate += @{
                DirectoryId = $row.DirectoryId
                UserName = $row.UserName
                BundleId = $row.BundleId
                ComputeTypeName = if ($row.ComputeTypeName) { $row.ComputeTypeName } else { 'VALUE' }
                RootVolumeSizeGib = if ($row.RootVolumeSizeGib) { [int]$row.RootVolumeSizeGib } else { 80 }
                UserVolumeSizeGib = if ($row.UserVolumeSizeGib) { [int]$row.UserVolumeSizeGib } else { 10 }
                RunningMode = if ($row.RunningMode) { $row.RunningMode } else { 'AUTO_STOP' }
            }
        }
    } else {
        $workspacesToCreate = $WorkspaceData
    }

    if ($workspacesToCreate.Count -eq 0) {
        Write-Warning "No WorkSpaces to create"
        exit 0
    }

    Write-Host "Planning to create $($workspacesToCreate.Count) WorkSpace(s)" -ForegroundColor Cyan

    if ($WhatIf) {
        Write-Host "WhatIf mode - showing planned operations:" -ForegroundColor Yellow
        foreach ($ws in $workspacesToCreate) {
            Write-Host "  Would create WorkSpace for user $($ws.UserName) in directory $($ws.DirectoryId)" -ForegroundColor Yellow
        }
        exit 0
    }

    $successful = 0
    $failed = 0
    $results = @()

    foreach ($ws in $workspacesToCreate) {
        try {
            Write-Host "Creating WorkSpace for user $($ws.UserName)..." -ForegroundColor Cyan

            # Validate required fields
            if (-not $ws.DirectoryId -or -not $ws.UserName -or -not $ws.BundleId) {
                throw "Missing required fields: DirectoryId, UserName, or BundleId"
            }

            $workspaceRequest = @{
                DirectoryId = $ws.DirectoryId
                UserName = $ws.UserName
                BundleId = $ws.BundleId
                WorkspaceProperties_ComputeTypeName = $ws.ComputeTypeName
                WorkspaceProperties_RootVolumeSizeGib = $ws.RootVolumeSizeGib
                WorkspaceProperties_UserVolumeSizeGib = $ws.UserVolumeSizeGib
                WorkspaceProperties_RunningMode = $ws.RunningMode
            }

            $workspace = New-WKSWorkspace @workspaceRequest

            $results += @{
                UserName = $ws.UserName
                WorkspaceId = $workspace.WorkspaceId
                Status = 'Success'
                Message = 'Created successfully'
            }

            Write-Host "  ✓ Created WorkSpace $($workspace.WorkspaceId) for user $($ws.UserName)" -ForegroundColor Green
            $successful++

        } catch {
            $results += @{
                UserName = $ws.UserName
                WorkspaceId = 'N/A'
                Status = 'Failed'
                Message = $_.Exception.Message
            }

            Write-Host "  ✗ Failed to create WorkSpace for user $($ws.UserName): $_" -ForegroundColor Red
            $failed++
        }
    }

    Write-Host ""
    Write-Host "Bulk creation summary:" -ForegroundColor Cyan
    Write-Host "  Successful: $successful" -ForegroundColor Green
    Write-Host "  Failed: $failed" -ForegroundColor Red
    Write-Host "  Total: $($workspacesToCreate.Count)" -ForegroundColor White

    # Display results table
    $results | ForEach-Object { [PSCustomObject]$_ } | Format-Table -AutoSize

    return $results
} catch {
    Write-Error "Bulk WorkSpace creation failed: $_"
    exit 1
}
