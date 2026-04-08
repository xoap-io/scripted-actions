<#
.SYNOPSIS
    Migrate an AWS WorkSpace to a different bundle.

.DESCRIPTION
    This script migrates an AWS WorkSpace to a new bundle using the Move-WKSWorkspace cmdlet from AWS.Tools.WorkSpaces.
    Validates that the WorkSpace and target bundle exist and that the WorkSpace is in a migratable state before proceeding.

.PARAMETER WorkspaceId
    The ID of the WorkSpace to migrate.

.PARAMETER TargetBundleId
    The ID of the target bundle to migrate the WorkSpace to.

.EXAMPLE
    .\aws-ps-workspaces-migrate-workspace.ps1 -WorkspaceId ws-abc12345 -TargetBundleId wsb-xyz98765

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace to migrate.")]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the target bundle to migrate the WorkSpace to (e.g. wsb-abc12345).")]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$TargetBundleId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating WorkSpace $WorkspaceId exists..." -ForegroundColor Cyan
    $workspace = Get-WKSWorkspace -WorkspaceId $WorkspaceId
    if (-not $workspace) {
        throw "WorkSpace $WorkspaceId not found"
    }

    if ($workspace.State -ne 'AVAILABLE' -and $workspace.State -ne 'STOPPED') {
        throw "WorkSpace $WorkspaceId is in state '$($workspace.State)' and cannot be migrated"
    }

    Write-Host "Validating target bundle $TargetBundleId exists..." -ForegroundColor Cyan
    $bundle = Get-WKSWorkspaceBundle -BundleId $TargetBundleId
    if (-not $bundle) {
        throw "Bundle $TargetBundleId not found"
    }

    if ($workspace.BundleId -eq $TargetBundleId) {
        Write-Warning "WorkSpace is already using bundle $TargetBundleId"
        exit 0
    }

    Write-Host "Current Bundle: $($workspace.BundleId)" -ForegroundColor Yellow
    Write-Host "Target Bundle: $TargetBundleId" -ForegroundColor Yellow
    Write-Host "Target Bundle Name: $($bundle.Name)" -ForegroundColor Yellow

    $confirmation = Read-Host "Are you sure you want to migrate WorkSpace $WorkspaceId to bundle $TargetBundleId? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Migration cancelled" -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Migrating WorkSpace to new bundle..." -ForegroundColor Cyan
    Move-WKSWorkspace -WorkspaceId $WorkspaceId -BundleId $TargetBundleId

    Write-Host "WorkSpace migration initiated successfully" -ForegroundColor Green
    Write-Host "The WorkSpace will be unavailable during migration" -ForegroundColor Yellow
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
