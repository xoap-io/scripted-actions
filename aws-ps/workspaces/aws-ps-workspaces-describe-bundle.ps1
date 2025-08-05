[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving bundle details for $BundleId..." -ForegroundColor Cyan
    
    $bundle = Get-WKSWorkspaceBundle -BundleId $BundleId
    
    if ($bundle) {
        Write-Host "Bundle Details:" -ForegroundColor Green
        Write-Host "  Bundle ID: $($bundle.BundleId)" -ForegroundColor White
        Write-Host "  Name: $($bundle.Name)" -ForegroundColor White
        Write-Host "  Description: $($bundle.Description)" -ForegroundColor White
        Write-Host "  Owner: $($bundle.Owner)" -ForegroundColor White
        Write-Host "  Image ID: $($bundle.ImageId)" -ForegroundColor White
        Write-Host "  Creation Time: $($bundle.CreationTime)" -ForegroundColor White
        Write-Host "  Last Updated: $($bundle.LastUpdatedTime)" -ForegroundColor White
        
        if ($bundle.RootStorage) {
            Write-Host "  Root Storage:" -ForegroundColor White
            Write-Host "    Capacity: $($bundle.RootStorage.Capacity) GB" -ForegroundColor Gray
        }
        
        if ($bundle.UserStorage) {
            Write-Host "  User Storage:" -ForegroundColor White
            Write-Host "    Capacity: $($bundle.UserStorage.Capacity) GB" -ForegroundColor Gray
        }
        
        if ($bundle.ComputeType) {
            Write-Host "  Compute Type:" -ForegroundColor White
            Write-Host "    Name: $($bundle.ComputeType.Name)" -ForegroundColor Gray
        }
        
        return $bundle
    } else {
        Write-Error "Bundle $BundleId not found"
        exit 1
    }
} catch {
    Write-Error "Failed to describe bundle: $_"
    exit 1
}
