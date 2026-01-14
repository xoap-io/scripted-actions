[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId,
    [Parameter()]
    [switch]$Force
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

        if ($workspace.State -eq 'TERMINATING' -or $workspace.State -eq 'TERMINATED') {
            Write-Warning "WorkSpace $id is already terminated or terminating, skipping"
            continue
        }

        if (-not $Force) {
            $confirmation = Read-Host "Are you sure you want to delete WorkSpace $id for user $($workspace.UserName)? (y/N)"
            if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
                Write-Host "Skipping WorkSpace $id" -ForegroundColor Yellow
                continue
            }
        }

        Write-Host "Terminating WorkSpace $id..." -ForegroundColor Cyan
        Remove-WKSWorkspace -WorkspaceId $id
        Write-Host "WorkSpace $id termination initiated successfully" -ForegroundColor Green
    }
} catch {
    Write-Error "Failed to delete WorkSpace(s): $_"
    exit 1
}
