<#
.SYNOPSIS
    Registers a directory with Amazon WorkSpaces.

.DESCRIPTION
    This script registers a directory with Amazon WorkSpaces using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces register-workspace-directory

.PARAMETER AwsDirectoryId
    The identifier of the directory to register with WorkSpaces.

.EXAMPLE
    .\aws-cli-register-workspace-directory.ps1 -AwsDirectoryId "d-12345678"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/register-workspace-directory.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The identifier of the directory to register with WorkSpaces")]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    aws workspaces register-workspace-directory `
        --directory-id $AwsDirectoryId `
        --no-enable-work-docs
    Write-Host "Successfully registered directory $AwsDirectoryId with WorkSpaces." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
