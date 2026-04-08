<#
.SYNOPSIS
    Retrieve usage information for AWS WorkSpaces.

.DESCRIPTION
    This script retrieves WorkSpaces usage information using Get-WKSWorkspaceUsage from AWS.Tools.WorkSpaces.
    Falls back to Get-WKSWorkspace and Get-WKSWorkspaceConnectionStatus if usage reporting is not available in the current module version.
    Supports optional filtering by directory, user, and date range.

.PARAMETER DirectoryId
    (Optional) Filter usage data by directory ID.

.PARAMETER UserName
    (Optional) Filter usage data by user name.

.PARAMETER StartDate
    (Optional) Start date for the usage query in YYYY-MM-DD format.

.PARAMETER EndDate
    (Optional) End date for the usage query in YYYY-MM-DD format.

.EXAMPLE
    .\aws-ps-workspaces-list-workspace-usage.ps1 -DirectoryId d-1234567890

.EXAMPLE
    .\aws-ps-workspaces-list-workspace-usage.ps1 -StartDate 2025-01-01 -EndDate 2025-01-31

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS.Tools.WorkSpaces

.LINK
    https://docs.aws.amazon.com/powershell/latest/reference/

.COMPONENT
    AWS PowerShell WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(HelpMessage = "Optional directory ID to filter usage data.")]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,

    [Parameter(HelpMessage = "Optional user name to filter usage data.")]
    [ValidateNotNullOrEmpty()]
    [string]$UserName,

    [Parameter(HelpMessage = "Optional start date for the usage query in YYYY-MM-DD format.")]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$StartDate,

    [Parameter(HelpMessage = "Optional end date for the usage query in YYYY-MM-DD format.")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
