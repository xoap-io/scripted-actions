[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId,
    [Parameter(Mandatory)]
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
} catch {
    Write-Error "Failed to migrate WorkSpace: $_"
    exit 1
}
