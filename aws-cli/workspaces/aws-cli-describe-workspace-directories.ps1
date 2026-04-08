<#
.SYNOPSIS
    Describe AWS WorkSpaces directories.

.DESCRIPTION
    This script gets details about registered AWS WorkSpaces directories using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces describe-workspace-directories

.PARAMETER AwsDirectoryId
    The ID of the directory to describe (optional).

.EXAMPLE
    .\aws-cli-describe-workspace-directories.ps1 -AwsDirectoryId "d-12345678"

.EXAMPLE
    .\aws-cli-describe-workspace-directories.ps1

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/describe-workspace-directories.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "The ID of the directory to describe (optional)")]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    if ($AwsDirectoryId) {
        aws workspaces describe-workspace-directories --directory-ids $AwsDirectoryId
    } else {
        aws workspaces describe-workspace-directories
    }
    Write-Host "Successfully described WorkSpace directories." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
