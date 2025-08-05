[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating directory exists..." -ForegroundColor Cyan
    $directory = Get-WKSDirectory -DirectoryId $DirectoryId
    if (-not $directory) {
        throw "Directory $DirectoryId not found"
    }
    
    Write-Host "Retrieving users from directory $DirectoryId..." -ForegroundColor Cyan
    $users = Get-WKSUser -DirectoryId $DirectoryId
    
    if ($users) {
        Write-Host "Found $($users.Count) user(s) in directory ${DirectoryId}:" -ForegroundColor Green
        $users | Format-Table -Property UserName, FirstName, LastName, EmailAddress, Enabled -AutoSize
        
        return $users
    } else {
        Write-Host "No users found in directory $DirectoryId" -ForegroundColor Yellow
        return @()
    }
} catch {
    Write-Error "Failed to list WorkSpaces users: $_"
    exit 1
}
