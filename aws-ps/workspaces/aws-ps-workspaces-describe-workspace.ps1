[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkspaceId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Retrieving WorkSpace details for $WorkspaceId..." -ForegroundColor Cyan

    $workspace = Get-WKSWorkspace -WorkspaceId $WorkspaceId

    if ($workspace) {
        Write-Host "WorkSpace Details:" -ForegroundColor Green
        Write-Host "  WorkSpace ID: $($workspace.WorkspaceId)" -ForegroundColor White
        Write-Host "  User Name: $($workspace.UserName)" -ForegroundColor White
        Write-Host "  Directory ID: $($workspace.DirectoryId)" -ForegroundColor White
        Write-Host "  State: $($workspace.State)" -ForegroundColor White
        Write-Host "  Bundle ID: $($workspace.BundleId)" -ForegroundColor White
        Write-Host "  Computer Name: $($workspace.ComputerName)" -ForegroundColor White
        Write-Host "  IP Address: $($workspace.IpAddress)" -ForegroundColor White
        Write-Host "  Subnet ID: $($workspace.SubnetId)" -ForegroundColor White
        Write-Host "  Error Code: $($workspace.ErrorCode)" -ForegroundColor White
        Write-Host "  Error Message: $($workspace.ErrorMessage)" -ForegroundColor White

        if ($workspace.WorkspaceProperties) {
            Write-Host "  Properties:" -ForegroundColor White
            Write-Host "    Compute Type: $($workspace.WorkspaceProperties.ComputeTypeName)" -ForegroundColor White
            Write-Host "    Root Volume Size: $($workspace.WorkspaceProperties.RootVolumeSizeGib) GB" -ForegroundColor White
            Write-Host "    User Volume Size: $($workspace.WorkspaceProperties.UserVolumeSizeGib) GB" -ForegroundColor White
            Write-Host "    Running Mode: $($workspace.WorkspaceProperties.RunningMode)" -ForegroundColor White
            if ($workspace.WorkspaceProperties.RunningModeAutoStopTimeoutInMinutes) {
                Write-Host "    Auto Stop Timeout: $($workspace.WorkspaceProperties.RunningModeAutoStopTimeoutInMinutes) minutes" -ForegroundColor White
            }
        }

        if ($workspace.ModificationStates) {
            Write-Host "  Modification States:" -ForegroundColor White
            foreach ($state in $workspace.ModificationStates) {
                Write-Host "    $($state.Resource): $($state.State)" -ForegroundColor White
            }
        }

        return $workspace
    } else {
        Write-Error "WorkSpace $WorkspaceId not found"
        exit 1
    }
} catch {
    Write-Error "Failed to describe WorkSpace: $_"
    exit 1
}
