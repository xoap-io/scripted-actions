[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating WorkSpace $WorkspaceId exists..." -ForegroundColor Cyan
    $workspace = Get-WKSWorkspace -WorkspaceId $WorkspaceId
    if (-not $workspace) {
        throw "WorkSpace $WorkspaceId not found"
    }
    
    Write-Host "Retrieving tags for WorkSpace $WorkspaceId..." -ForegroundColor Cyan
    
    $tags = Get-WKSWorkspaceTag -WorkspaceId $WorkspaceId
    
    if ($tags -and $tags.Count -gt 0) {
        Write-Host "Found $($tags.Count) tag(s) for WorkSpace ${WorkspaceId}:" -ForegroundColor Green
        $tags | Format-Table -Property Key, Value -AutoSize
        
        return $tags
    } else {
        Write-Host "No tags found for WorkSpace $WorkspaceId" -ForegroundColor Yellow
        return @()
    }
} catch {
    Write-Error "Failed to list WorkSpace tags: $_"
    exit 1
}
