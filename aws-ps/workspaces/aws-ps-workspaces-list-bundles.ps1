[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId,
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Owner
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving WorkSpaces bundles..." -ForegroundColor Cyan
    
    $params = @{}
    if ($BundleId) { $params['BundleId'] = $BundleId }
    if ($Owner) { $params['Owner'] = $Owner }
    
    $bundles = Get-WKSWorkspaceBundle @params
    
    if ($bundles) {
        Write-Host "Found $($bundles.Count) bundle(s):" -ForegroundColor Green
        
        foreach ($bundle in $bundles) {
            Write-Host ""
            Write-Host "Bundle ID: $($bundle.BundleId)" -ForegroundColor White
            Write-Host "  Name: $($bundle.Name)" -ForegroundColor White
            Write-Host "  Description: $($bundle.Description)" -ForegroundColor White
            Write-Host "  Owner: $($bundle.Owner)" -ForegroundColor White
            
            if ($bundle.RootStorage) {
                Write-Host "  Root Storage:" -ForegroundColor White
                Write-Host "    Capacity: $($bundle.RootStorage.Capacity)" -ForegroundColor Gray
            }
            
            if ($bundle.UserStorage) {
                Write-Host "  User Storage:" -ForegroundColor White
                Write-Host "    Capacity: $($bundle.UserStorage.Capacity)" -ForegroundColor Gray
            }
            
            if ($bundle.ComputeType) {
                Write-Host "  Compute Type:" -ForegroundColor White
                Write-Host "    Name: $($bundle.ComputeType.Name)" -ForegroundColor Gray
            }
            
            Write-Host "  Image ID: $($bundle.ImageId)" -ForegroundColor White
            Write-Host "  Last Updated: $($bundle.LastUpdatedTime)" -ForegroundColor White
            Write-Host "  Creation Time: $($bundle.CreationTime)" -ForegroundColor White
        }
        
        return $bundles
    } else {
        Write-Host "No bundles found matching the specified criteria" -ForegroundColor Yellow
        return @()
    }
} catch {
    Write-Error "Failed to list bundles: $_"
    exit 1
}
