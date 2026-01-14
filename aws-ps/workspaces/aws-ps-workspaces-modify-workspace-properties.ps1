[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId,
    [Parameter()]
    [ValidateSet('VALUE','STANDARD','PERFORMANCE','POWER','GRAPHICS','POWERPRO','GRAPHICSPRO')]
    [string]$ComputeTypeName,
    [Parameter()]
    [ValidateRange(80, 2000)]
    [int]$RootVolumeSizeGib,
    [Parameter()]
    [ValidateRange(10, 2000)]
    [int]$UserVolumeSizeGib,
    [Parameter()]
    [ValidateSet('ALWAYS_ON','AUTO_STOP')]
    [string]$RunningMode,
    [Parameter()]
    [ValidateRange(60, 36000)]
    [int]$RunningModeAutoStopTimeoutInMinutes
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating WorkSpace $WorkspaceId exists..." -ForegroundColor Cyan
    $workspace = Get-WKSWorkspace -WorkspaceId $WorkspaceId
    if (-not $workspace) {
        throw "WorkSpace $WorkspaceId not found"
    }

    if ($workspace.State -ne 'AVAILABLE' -and $workspace.State -ne 'STOPPED') {
        throw "WorkSpace $WorkspaceId is in state '$($workspace.State)' and cannot be modified"
    }

    Write-Host "Modifying WorkSpace properties..." -ForegroundColor Cyan

    $modifyParams = @{
        WorkspaceId = $WorkspaceId
    }

    $properties = @{}

    if ($ComputeTypeName) {
        $properties['ComputeTypeName'] = $ComputeTypeName
        Write-Host "  Setting Compute Type to: $ComputeTypeName" -ForegroundColor Yellow
    }
    if ($RootVolumeSizeGib) {
        $properties['RootVolumeSizeGib'] = $RootVolumeSizeGib
        Write-Host "  Setting Root Volume Size to: $RootVolumeSizeGib GB" -ForegroundColor Yellow
    }
    if ($UserVolumeSizeGib) {
        $properties['UserVolumeSizeGib'] = $UserVolumeSizeGib
        Write-Host "  Setting User Volume Size to: $UserVolumeSizeGib GB" -ForegroundColor Yellow
    }
    if ($RunningMode) {
        $properties['RunningMode'] = $RunningMode
        Write-Host "  Setting Running Mode to: $RunningMode" -ForegroundColor Yellow
    }
    if ($RunningModeAutoStopTimeoutInMinutes -and $RunningMode -eq 'AUTO_STOP') {
        $properties['RunningModeAutoStopTimeoutInMinutes'] = $RunningModeAutoStopTimeoutInMinutes
        Write-Host "  Setting Auto Stop Timeout to: $RunningModeAutoStopTimeoutInMinutes minutes" -ForegroundColor Yellow
    }

    if ($properties.Count -eq 0) {
        Write-Warning "No properties specified for modification"
        exit 0
    }

    $modifyParams['WorkspaceProperties'] = $properties

    Edit-WKSWorkspaceProperty @modifyParams

    Write-Host "WorkSpace properties modified successfully" -ForegroundColor Green
    Write-Host "Note: Some changes may require a reboot to take effect" -ForegroundColor Yellow
} catch {
    Write-Error "Failed to modify WorkSpace properties: $_"
    exit 1
}
