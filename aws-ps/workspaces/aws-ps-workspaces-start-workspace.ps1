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

        if ($workspace.State -eq 'AVAILABLE') {
            Write-Warning "WorkSpace $id is already running, skipping"
            continue
        }

        if ($workspace.State -ne 'STOPPED') {
            Write-Warning "WorkSpace $id is in state '$($workspace.State)' and cannot be started, skipping"
            continue
        }

        Write-Host "Starting WorkSpace $id..." -ForegroundColor Cyan
        Start-WKSWorkspace -WorkspaceId $id
        Write-Host "WorkSpace $id start initiated successfully" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to start WorkSpace(s): $_"
    exit 1
}
