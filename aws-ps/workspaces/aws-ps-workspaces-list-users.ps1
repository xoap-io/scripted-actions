<#
.SYNOPSIS
    List users in an AWS WorkSpaces directory.

.DESCRIPTION
    This script retrieves and lists users in an AWS WorkSpaces directory using the Get-WKSUser cmdlet from AWS.Tools.WorkSpaces.

.PARAMETER DirectoryId
    The ID of the WorkSpaces directory to list users from.

.EXAMPLE
    .\aws-ps-workspaces-list-users.ps1 -DirectoryId d-1234567890

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
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpaces directory to list users from.")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
