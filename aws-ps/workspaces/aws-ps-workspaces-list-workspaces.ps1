<#
.SYNOPSIS
    List AWS WorkSpaces with optional filtering.

.DESCRIPTION
    This script retrieves and lists AWS WorkSpaces using the Get-WKSWorkspace cmdlet from AWS.Tools.WorkSpaces.
    Supports optional filtering by directory, user name, state, and bundle ID.

.PARAMETER DirectoryId
    (Optional) Filter WorkSpaces by directory ID.

.PARAMETER UserName
    (Optional) Filter WorkSpaces by user name.

.PARAMETER State
    (Optional) Filter WorkSpaces by state.

.PARAMETER BundleId
    (Optional) Filter WorkSpaces by bundle ID.

.EXAMPLE
    .\aws-ps-workspaces-list-workspaces.ps1

.EXAMPLE
    .\aws-ps-workspaces-list-workspaces.ps1 -State AVAILABLE -DirectoryId d-1234567890

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
    [Parameter(HelpMessage = "Optional directory ID to filter WorkSpaces.")]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,

    [Parameter(HelpMessage = "Optional user name to filter WorkSpaces (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,

    [Parameter(HelpMessage = "Optional state to filter WorkSpaces.")]
    [ValidateSet('PENDING','AVAILABLE','IMPAIRED','UNHEALTHY','REBOOTING','STARTING','REBUILDING','RESTORING','MAINTENANCE','ADMIN_MAINTENANCE','TERMINATING','TERMINATED','SUSPENDED','UPDATING','STOPPING','STOPPED','ERROR')]
    [string]$State,

    [Parameter(HelpMessage = "Optional bundle ID to filter WorkSpaces (e.g. wsb-abc12345).")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
