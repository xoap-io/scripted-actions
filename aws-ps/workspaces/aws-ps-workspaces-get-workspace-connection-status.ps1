[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId
)

$ErrorActionPreference = 'Stop'

try {
    foreach ($id in $WorkspaceId) {
        Write-Host "Retrieving connection status for WorkSpace $id..." -ForegroundColor Cyan
        
        $workspace = Get-WKSWorkspace -WorkspaceId $id
        if (-not $workspace) {
            Write-Warning "WorkSpace $id not found, skipping"
            continue
        }
        
        $connectionStatus = Get-WKSWorkspaceConnectionStatus -WorkspaceId $id
        
        if ($connectionStatus) {
            Write-Host "Connection Status for WorkSpace ${id}:" -ForegroundColor Green
            Write-Host "  WorkSpace ID: $($connectionStatus.WorkspaceId)" -ForegroundColor White
            Write-Host "  Connection State: $($connectionStatus.ConnectionState)" -ForegroundColor White
            Write-Host "  Connection State Check Timestamp: $($connectionStatus.ConnectionStateCheckTimestamp)" -ForegroundColor White
            Write-Host "  Last Known User Connection Timestamp: $($connectionStatus.LastKnownUserConnectionTimestamp)" -ForegroundColor White
        } else {
            Write-Warning "No connection status available for WorkSpace $id"
        }
        Write-Host ""
    }
} catch {
    Write-Error "Failed to get WorkSpace connection status: $_"
    exit 1
}
