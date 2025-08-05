[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId
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
        
        if ($workspace.State -eq 'STOPPED') {
            Write-Warning "WorkSpace $id is already stopped, skipping"
            continue
        }
        
        if ($workspace.State -ne 'AVAILABLE') {
            Write-Warning "WorkSpace $id is in state '$($workspace.State)' and cannot be stopped, skipping"
            continue
        }
        
        Write-Host "Stopping WorkSpace $id..." -ForegroundColor Cyan
        Stop-WKSWorkspace -WorkspaceId $id
        Write-Host "WorkSpace $id stop initiated successfully" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to stop WorkSpace(s): $_"
    exit 1
}
