[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,
    [Parameter(Mandatory)]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$BundleId,
    [Parameter()]
    [ValidateSet('VALUE','STANDARD','PERFORMANCE','POWER','GRAPHICS','POWERPRO','GRAPHICSPRO')]
    [string]$ComputeTypeName = 'VALUE',
    [Parameter()]
    [ValidateRange(80, 2000)]
    [int]$RootVolumeSizeGib = 80,
    [Parameter()]
    [ValidateRange(10, 2000)]
    [int]$UserVolumeSizeGib = 10,
    [Parameter()]
    [ValidateSet('ALWAYS_ON','AUTO_STOP')]
    [string]$RunningMode = 'AUTO_STOP',
    [Parameter()]
    [ValidateRange(60, 36000)]
    [int]$RunningModeAutoStopTimeoutInMinutes = 60,
    [Parameter()]
    [hashtable]$Tags = @{}
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating directory exists..." -ForegroundColor Cyan
    $directory = Get-WKSDirectory -DirectoryId $DirectoryId
    if (-not $directory) {
        throw "Directory $DirectoryId not found"
    }

    Write-Host "Validating bundle exists..." -ForegroundColor Cyan
    $bundle = Get-WKSWorkspaceBundle -BundleId $BundleId
    if (-not $bundle) {
        throw "Bundle $BundleId not found"
    }

    Write-Host "Creating WorkSpace for user $UserName..." -ForegroundColor Cyan

    $workspaceRequest = @{
        DirectoryId = $DirectoryId
        UserName = $UserName
        BundleId = $BundleId
        WorkspaceProperties_ComputeTypeName = $ComputeTypeName
        WorkspaceProperties_RootVolumeSizeGib = $RootVolumeSizeGib
        WorkspaceProperties_UserVolumeSizeGib = $UserVolumeSizeGib
        WorkspaceProperties_RunningMode = $RunningMode
    }

    if ($RunningMode -eq 'AUTO_STOP') {
        $workspaceRequest['WorkspaceProperties_RunningModeAutoStopTimeoutInMinutes'] = $RunningModeAutoStopTimeoutInMinutes
    }

    if ($Tags.Count -gt 0) {
        $workspaceRequest['Tags'] = $Tags.GetEnumerator() | ForEach-Object { @{Key=$_.Key; Value=$_.Value} }
    }

    $workspace = New-WKSWorkspace @workspaceRequest

    Write-Host "WorkSpace created successfully:" -ForegroundColor Green
    Write-Host "  WorkSpace ID: $($workspace.WorkspaceId)" -ForegroundColor Green
    Write-Host "  State: $($workspace.State)" -ForegroundColor Green
    Write-Host "  User Name: $($workspace.UserName)" -ForegroundColor Green
    Write-Host "  Bundle ID: $($workspace.BundleId)" -ForegroundColor Green

    return $workspace
} catch {
    Write-Error "Failed to create WorkSpace: $_"
    exit 1
}
