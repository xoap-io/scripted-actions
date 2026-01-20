<#
.SYNOPSIS
    Describe AWS WorkSpaces.
.DESCRIPTION
    This script lists and filters AWS WorkSpaces by directory, user, bundle, or state using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsDirectoryId
    (Optional) The ID of the AWS Directory to filter WorkSpaces.
.PARAMETER AwsUserName
    (Optional) The user name to filter WorkSpaces.
.PARAMETER AwsWorkspaceBundleId
    (Optional) The bundle ID to filter WorkSpaces.
.PARAMETER AwsWorkspaceState
    (Optional) The state to filter WorkSpaces.
.EXAMPLE
    .\aws-cli-describe-workspaces.ps1 -AwsDirectoryId d-12345678 -AwsUserName johndoe
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId,
    [Parameter()]
    [ValidatePattern('^[a-zA-Z0-9._@-]{1,64}$')]
    [string]$AwsUserName,
    [Parameter()]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceBundleId,
    [Parameter()]
    [ValidateSet('AVAILABLE','ERROR','REBOOTING','STARTING','STOPPED','STOPPING','TERMINATED')]
    [string]$AwsWorkspaceState
)

$ErrorActionPreference = 'Stop'
try {
    $filters = @()
    if ($AwsDirectoryId) { $filters += "Name=directory-id,Values=$AwsDirectoryId" }
    if ($AwsUserName)    { $filters += "Name=user-name,Values=$AwsUserName" }
    if ($AwsWorkspaceBundleId) { $filters += "Name=bundle-id,Values=$AwsWorkspaceBundleId" }
    if ($AwsWorkspaceState) { $filters += "Name=state,Values=$AwsWorkspaceState" }
    $filterArgs = $filters -join ' '
    $cmd = "aws workspaces describe-workspaces"
    if ($filterArgs) { $cmd += " --filters $filterArgs" }
    Invoke-Expression $cmd
    Write-Host "Successfully described WorkSpaces."
} catch {
    Write-Error "Failed to describe WorkSpaces: $_"
    exit 1
}
