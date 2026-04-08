<#
.SYNOPSIS
    Create a new AWS WorkSpace.

.DESCRIPTION
    This script creates a new AWS WorkSpace using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces create-workspaces

.PARAMETER AwsDirectoryId
    The ID of the AWS Directory to register the WorkSpace with.

.PARAMETER AwsWorkspaceBundleId
    The ID of the WorkSpace bundle to use.

.PARAMETER AwsUserName
    The user name for the WorkSpace.

.PARAMETER AwsRunningMode
    The running mode for the WorkSpace (AUTO_STOP or ALWAYS_ON).

.EXAMPLE
    .\aws-cli-create-workspace.ps1 -AwsDirectoryId "d-12345678" -AwsWorkspaceBundleId "wsb-12345678" -AwsUserName "johndoe" -AwsRunningMode "AUTO_STOP"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/create-workspaces.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS Directory to register the WorkSpace with")]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId,

    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace bundle to use")]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceBundleId,

    [Parameter(Mandatory = $true, HelpMessage = "The user name for the WorkSpace")]
    [ValidatePattern('^[a-zA-Z0-9._@-]{1,64}$')]
    [string]$AwsUserName,

    [Parameter(Mandatory = $true, HelpMessage = "The running mode for the WorkSpace (AUTO_STOP or ALWAYS_ON)")]
    [ValidateSet('AUTO_STOP', 'ALWAYS_ON')]
    [string]$AwsRunningMode
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    aws workspaces create-workspaces `
        --workspaces DirectoryId=$AwsDirectoryId,BundleId=$AwsWorkspaceBundleId,UserName=$AwsUserName,RunningMode=$AwsRunningMode
    Write-Host "Successfully created WorkSpace for user $AwsUserName in directory $AwsDirectoryId." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
