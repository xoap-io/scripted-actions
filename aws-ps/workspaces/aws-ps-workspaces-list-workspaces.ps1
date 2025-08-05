[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,
    [Parameter()]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,
    [Parameter()]
    [ValidateSet('PENDING','AVAILABLE','IMPAIRED','UNHEALTHY','REBOOTING','STARTING','REBUILDING','RESTORING','MAINTENANCE','ADMIN_MAINTENANCE','TERMINATING','TERMINATED','SUSPENDED','UPDATING','STOPPING','STOPPED','ERROR')]
    [string]$State,
    [Parameter()]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving WorkSpaces..." -ForegroundColor Cyan
    
    $params = @{}
    if ($DirectoryId) { $params['DirectoryId'] = $DirectoryId }
    if ($UserName) { $params['UserName'] = $UserName }
    if ($BundleId) { $params['BundleId'] = $BundleId }
    
    $workspaces = Get-WKSWorkspace @params
    
    if ($State) {
        $workspaces = $workspaces | Where-Object { $_.State -eq $State }
    }
    
    if ($workspaces) {
        Write-Host "Found $($workspaces.Count) WorkSpace(s):" -ForegroundColor Green
        $workspaces | Format-Table -Property WorkspaceId, UserName, State, BundleId, ComputerName, IpAddress -AutoSize
        
        return $workspaces
    } else {
        Write-Host "No WorkSpaces found matching the specified criteria" -ForegroundColor Yellow
        return @()
    }
} catch {
    Write-Error "Failed to list WorkSpaces: $_"
    exit 1
}
