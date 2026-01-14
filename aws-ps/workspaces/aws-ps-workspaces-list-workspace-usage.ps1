[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,
    [Parameter()]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$StartDate,
    [Parameter()]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$EndDate
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving WorkSpaces usage information..." -ForegroundColor Cyan

    $params = @{}
    if ($DirectoryId) { $params['DirectoryId'] = $DirectoryId }
    if ($UserName) { $params['UserName'] = $UserName }
    if ($StartDate) { $params['StartTime'] = [DateTime]::Parse($StartDate) }
    if ($EndDate) { $params['EndTime'] = [DateTime]::Parse($EndDate) }

    # Note: This cmdlet may not exist in all AWS PowerShell versions
    # This is a placeholder for usage reporting functionality
    try {
        $usage = Get-WKSWorkspaceUsage @params

        if ($usage) {
            Write-Host "Found usage data:" -ForegroundColor Green
            $usage | Format-Table -Property WorkspaceId, UserName, DirectoryId, LastConnectionTime, UsageHours -AutoSize

            return $usage
        } else {
            Write-Host "No usage data found for the specified criteria" -ForegroundColor Yellow
            return @()
        }
    } catch {
        Write-Warning "WorkSpaces usage reporting may not be available in this AWS PowerShell version"
        Write-Host "Alternative: Use CloudWatch metrics or AWS Cost Explorer for usage data" -ForegroundColor Yellow

        # Fallback: Show WorkSpaces with their last known connection times
        $workspaces = Get-WKSWorkspace @params

        if ($workspaces) {
            Write-Host "Current WorkSpaces information:" -ForegroundColor Green
            foreach ($ws in $workspaces) {
                $connectionStatus = Get-WKSWorkspaceConnectionStatus -WorkspaceId $ws.WorkspaceId
                Write-Host "WorkSpace: $($ws.WorkspaceId), User: $($ws.UserName), State: $($ws.State)" -ForegroundColor White
                if ($connectionStatus.LastKnownUserConnectionTimestamp) {
                    Write-Host "  Last Connection: $($connectionStatus.LastKnownUserConnectionTimestamp)" -ForegroundColor Gray
                }
            }
        }
    }
} catch {
    Write-Error "Failed to retrieve WorkSpaces usage: $_"
    exit 1
}
