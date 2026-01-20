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

        if ($workspace.State -ne 'AVAILABLE' -and $workspace.State -ne 'STOPPED') {
            Write-Warning "WorkSpace $id is in state '$($workspace.State)' and cannot be rebooted, skipping"
            continue
        }

        Write-Host "Rebooting WorkSpace $id..." -ForegroundColor Cyan
        Restart-WKSWorkspace -WorkspaceId $id
        Write-Host "WorkSpace $id reboot initiated successfully" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to reboot WorkSpace(s): $_"
    exit 1
}
