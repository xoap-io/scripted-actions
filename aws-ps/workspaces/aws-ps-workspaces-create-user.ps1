[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,
    [Parameter(Mandatory)]
    [System.Security.SecureString]$Password,
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$FirstName,
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$LastName,
    [Parameter()]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$EmailAddress
)

$ErrorActionPreference = 'Stop'

try {
    Write-Host "Validating directory exists..." -ForegroundColor Cyan
    $directory = Get-WKSDirectory -DirectoryId $DirectoryId
    if (-not $directory) {
        throw "Directory $DirectoryId not found"
    }
    
    Write-Host "Creating WorkSpaces user $UserName..." -ForegroundColor Cyan
    
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    
    $params = @{
        DirectoryId = $DirectoryId
        UserName = $UserName
        Password = $plainPassword
    }
    
    if ($FirstName) { $params['FirstName'] = $FirstName }
    if ($LastName) { $params['LastName'] = $LastName }
    if ($EmailAddress) { $params['EmailAddress'] = $EmailAddress }
    
    $result = New-WKSUser @params
    
    Write-Host "User $UserName created successfully in directory $DirectoryId" -ForegroundColor Green
    
    return $result
} catch {
    Write-Error "Failed to create WorkSpaces user: $_"
    exit 1
}
