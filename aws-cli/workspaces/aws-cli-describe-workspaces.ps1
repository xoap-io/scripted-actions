<#
.SYNOPSIS
    Describe AWS WorkSpaces.

.DESCRIPTION
    This script lists and filters AWS WorkSpaces by directory, user, bundle, or state using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces describe-workspaces

.PARAMETER AwsDirectoryId
    The ID of the AWS Directory to filter WorkSpaces (optional).

.PARAMETER AwsUserName
    The user name to filter WorkSpaces (optional).

.PARAMETER AwsWorkspaceBundleId
    The bundle ID to filter WorkSpaces (optional).

.PARAMETER AwsWorkspaceState
    The state to filter WorkSpaces (optional).

.EXAMPLE
    .\aws-cli-describe-workspaces.ps1 -AwsDirectoryId "d-12345678" -AwsUserName "johndoe"

.EXAMPLE
    .\aws-cli-describe-workspaces.ps1

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
    [Parameter(Mandatory = $false, HelpMessage = "The ID of the AWS Directory to filter WorkSpaces")]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId,

    [Parameter(Mandatory = $false, HelpMessage = "The user name to filter WorkSpaces")]
    [ValidatePattern('^[a-zA-Z0-9._@-]{1,64}$')]
    [string]$AwsUserName,

    [Parameter(Mandatory = $false, HelpMessage = "The bundle ID to filter WorkSpaces")]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceBundleId,

    [Parameter(Mandatory = $false, HelpMessage = "The state to filter WorkSpaces")]
    [ValidateSet('AVAILABLE', 'ERROR', 'REBOOTING', 'STARTING', 'STOPPED', 'STOPPING', 'TERMINATED')]
    [string]$AwsWorkspaceState
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $filters = @()
    if ($AwsDirectoryId) { $filters += "Name=directory-id,Values=$AwsDirectoryId" }
    if ($AwsUserName) { $filters += "Name=user-name,Values=$AwsUserName" }
    if ($AwsWorkspaceBundleId) { $filters += "Name=bundle-id,Values=$AwsWorkspaceBundleId" }
    if ($AwsWorkspaceState) { $filters += "Name=state,Values=$AwsWorkspaceState" }
    $filterArgs = $filters -join ' '
    $cmd = "aws workspaces describe-workspaces"
    if ($filterArgs) { $cmd += " --filters $filterArgs" }
    Invoke-Expression $cmd
    Write-Host "Successfully described WorkSpaces." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
