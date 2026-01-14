[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$WorkspaceId,
    [Parameter(Mandatory)]
    [hashtable]$Tags
)

$ErrorActionPreference = 'Stop'

try {
    if ($Tags.Count -eq 0) {
        Write-Warning "No tags specified"
        exit 0
    }

    foreach ($id in $WorkspaceId) {
        Write-Host "Validating WorkSpace $id exists..." -ForegroundColor Cyan
        $workspace = Get-WKSWorkspace -WorkspaceId $id
        if (-not $workspace) {
            Write-Warning "WorkSpace $id not found, skipping"
            continue
        }

        Write-Host "Adding tags to WorkSpace $id..." -ForegroundColor Cyan

        $tagList = $Tags.GetEnumerator() | ForEach-Object { @{Key=$_.Key; Value=$_.Value} }

        New-WKSWorkspaceTag -WorkspaceId $id -Tags $tagList

        Write-Host "Tags added successfully to WorkSpace ${id}:" -ForegroundColor Green
        foreach ($tag in $Tags.GetEnumerator()) {
            Write-Host "  $($tag.Key): $($tag.Value)" -ForegroundColor White
        }
    }
} catch {
    Write-Error "Failed to tag WorkSpace(s): $_"
    exit 1
}
