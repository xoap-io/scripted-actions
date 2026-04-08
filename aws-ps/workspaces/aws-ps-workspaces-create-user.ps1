<#
.SYNOPSIS
    Create a user in an AWS WorkSpaces directory.

.DESCRIPTION
    This script creates a user in an AWS WorkSpaces directory using the New-WKSUser cmdlet from AWS.Tools.WorkSpaces.
    Validates that the directory exists before creating the user.

.PARAMETER DirectoryId
    The ID of the WorkSpaces directory in which to create the user.

.PARAMETER UserName
    The user name for the new user.

.PARAMETER Password
    The password for the new user as a SecureString.

.PARAMETER FirstName
    (Optional) The first name of the user.

.PARAMETER LastName
    (Optional) The last name of the user.

.PARAMETER EmailAddress
    (Optional) The email address of the user.

.EXAMPLE
    .\aws-ps-workspaces-create-user.ps1 -DirectoryId d-1234567890 -UserName jdoe -Password (Read-Host -AsSecureString)

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpaces directory.")]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,

    [Parameter(Mandatory = $true, HelpMessage = "The user name for the new user (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,

    [Parameter(Mandatory = $true, HelpMessage = "The password for the new user as a SecureString.")]
    [System.Security.SecureString]$Password,

    [Parameter(HelpMessage = "The first name of the user.")]
    [ValidateNotNullOrEmpty()]
    [string]$FirstName,

    [Parameter(HelpMessage = "The last name of the user.")]
    [ValidateNotNullOrEmpty()]
    [string]$LastName,

    [Parameter(HelpMessage = "The email address of the user.")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
