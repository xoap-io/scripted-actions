[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating directory exists..." -ForegroundColor Cyan
    $directory = Get-WKSDirectory -DirectoryId $DirectoryId
    if (-not $directory) {
        throw "Directory $DirectoryId not found"
    }

    # Check if user has any active WorkSpaces
    Write-Host "Checking for active WorkSpaces for user $UserName..." -ForegroundColor Cyan
    $workspaces = Get-WKSWorkspace -DirectoryId $DirectoryId | Where-Object { $_.UserName -eq $UserName -and $_.State -ne 'TERMINATED' }

    if ($workspaces -and -not $Force) {
        Write-Warning "User $UserName has $($workspaces.Count) active WorkSpace(s). Use -Force to delete anyway."
        Write-Host "Active WorkSpaces:" -ForegroundColor Yellow
        $workspaces | Format-Table -Property WorkspaceId, State -AutoSize
        exit 1
    }

    if (-not $Force) {
        $confirmation = Read-Host "Are you sure you want to delete user $UserName from directory $DirectoryId? (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Host "User deletion cancelled" -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Host "Deleting WorkSpaces user $UserName..." -ForegroundColor Cyan
    Remove-WKSUser -DirectoryId $DirectoryId -UserName $UserName

    Write-Host "User $UserName deleted successfully from directory $DirectoryId" -ForegroundColor Green
} catch {
    Write-Error "Failed to delete WorkSpaces user: $_"
    exit 1
}
