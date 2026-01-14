[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId,
    [Parameter(Mandatory)]
    [string[]]$TagKeys
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

        Write-Host "Removing tags from WorkSpace $id..." -ForegroundColor Cyan

        Remove-WKSWorkspaceTag -WorkspaceId $id -TagKeys $TagKeys

        Write-Host "Tags removed successfully from WorkSpace ${id}:" -ForegroundColor Green
        foreach ($key in $TagKeys) {
            Write-Host "  $key" -ForegroundColor White
        }
    }
} catch {
    Write-Error "Failed to untag WorkSpace(s): $_"
    exit 1
}
