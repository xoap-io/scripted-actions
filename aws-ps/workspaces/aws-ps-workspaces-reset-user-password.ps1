<#
.SYNOPSIS
    Reset a user password in an AWS WorkSpaces directory.

.DESCRIPTION
    This script resets the password for a user in an AWS WorkSpaces directory using the Reset-WKSUserPassword cmdlet from AWS.Tools.WorkSpaces.

.PARAMETER DirectoryId
    The ID of the WorkSpaces directory containing the user.

.PARAMETER UserName
    The user name of the user whose password to reset.

.PARAMETER NewPassword
    The new password as a SecureString.

.EXAMPLE
    .\aws-ps-workspaces-reset-user-password.ps1 -DirectoryId d-1234567890 -UserName jdoe -NewPassword (Read-Host -AsSecureString)

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpaces directory containing the user.")]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryId,

    [Parameter(Mandatory = $true, HelpMessage = "The user name of the user whose password to reset (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,

    [Parameter(Mandatory = $true, HelpMessage = "The new password as a SecureString.")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
