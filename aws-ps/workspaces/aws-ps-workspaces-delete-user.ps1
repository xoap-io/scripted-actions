<#
.SYNOPSIS
    Delete a user from an AWS WorkSpaces directory.

.DESCRIPTION
    This script deletes a user from an AWS WorkSpaces directory using the Remove-WKSUser cmdlet from AWS.Tools.WorkSpaces.
    Checks for active WorkSpaces before deletion unless -Force is specified.

.PARAMETER DirectoryId
    The ID of the WorkSpaces directory from which to delete the user.

.PARAMETER UserName
    The user name of the user to delete.

.PARAMETER Force
    Switch to skip confirmation prompts and active WorkSpace checks.

.EXAMPLE
    .\aws-ps-workspaces-delete-user.ps1 -DirectoryId d-1234567890 -UserName jdoe -Force

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

    [Parameter(Mandatory = $true, HelpMessage = "The user name of the user to delete (alphanumeric, dots, dashes, up to 64 characters).")]
    [ValidatePattern('^[a-zA-Z0-9._@\-]{1,64}$')]
    [string]$UserName,

    [Parameter(HelpMessage = "Switch to skip confirmation prompts and active WorkSpace checks.")]
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
}
catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
