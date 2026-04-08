<#
.SYNOPSIS
    Bulk create AWS WorkSpaces from a CSV file or array.

.DESCRIPTION
    This script creates multiple AWS WorkSpaces in bulk using the New-WKSWorkspace cmdlet from AWS.Tools.WorkSpaces.
    Input can be provided as a CSV file path or as an array of hashtables. Supports WhatIf mode for previewing operations.

.PARAMETER CsvFilePath
    Path to a CSV file containing WorkSpace definitions. Required columns: DirectoryId, UserName, BundleId.
    Optional columns: ComputeTypeName, RootVolumeSizeGib, UserVolumeSizeGib, RunningMode.

.PARAMETER WorkspaceData
    Array of hashtables defining WorkSpaces to create. Each hashtable must contain: DirectoryId, UserName, BundleId.

.PARAMETER WhatIf
    Switch to preview which WorkSpaces would be created without actually creating them.

.EXAMPLE
    .\aws-ps-workspaces-bulk-create.ps1 -CsvFilePath ./workspaces.csv

.EXAMPLE
    .\aws-ps-workspaces-bulk-create.ps1 -WorkspaceData @(@{DirectoryId='d-1234567890';UserName='user1';BundleId='wsb-abc12345'})

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
    [Parameter(Mandatory = $true, ParameterSetName = 'CsvFile', HelpMessage = "Path to the CSV file containing WorkSpace definitions.")]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [string]$CsvFilePath,

    [Parameter(Mandatory = $true, ParameterSetName = 'Array', HelpMessage = "Array of hashtables defining WorkSpaces to create. Each must contain DirectoryId, UserName, BundleId.")]
    [hashtable[]]$WorkspaceData,

    [Parameter(HelpMessage = "Switch to preview which WorkSpaces would be created without actually creating them.")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
