<#
.SYNOPSIS
    List users assigned to AWS WorkSpaces in a directory.

.DESCRIPTION
    This script lists users assigned to WorkSpaces in a specified directory using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces describe-workspaces

.PARAMETER AwsDirectoryId
    The ID of the directory to list users for.

.EXAMPLE
    .\aws-cli-list-workspace-users.ps1 -AwsDirectoryId "d-12345678"

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions.
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no
    liability for the function, the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

    Author: XOAP.IO
    Requires: AWS CLI v2 (https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)

.LINK
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/describe-workspaces.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the directory to list users for")]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $workspaces = aws workspaces describe-workspaces --directory-id $AwsDirectoryId | ConvertFrom-Json
    $users = $workspaces.Workspaces | Select-Object -ExpandProperty UserName | Sort-Object -Unique
    Write-Host "Users assigned to WorkSpaces in directory ${AwsDirectoryId}:" -ForegroundColor Green
    $users | ForEach-Object { Write-Host $_ }
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
