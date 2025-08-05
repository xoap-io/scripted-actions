[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,
    [Parameter(Mandatory)]
    [System.Security.SecureString]$NewPassword
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating directory exists..." -ForegroundColor Cyan
    $directory = Get-WKSDirectory -DirectoryId $DirectoryId
    if (-not $directory) {
        throw "Directory $DirectoryId not found"
    }
    
    Write-Host "Resetting password for user $UserName..." -ForegroundColor Cyan
    
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))
    
    Reset-WKSUserPassword -DirectoryId $DirectoryId -UserName $UserName -NewPassword $plainPassword
    
    Write-Host "Password reset successfully for user $UserName in directory $DirectoryId" -ForegroundColor Green
} catch {
    Write-Error "Failed to reset WorkSpaces user password: $_"
    exit 1
}
