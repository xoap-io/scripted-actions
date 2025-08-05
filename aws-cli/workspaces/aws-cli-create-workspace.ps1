<#
.SYNOPSIS
    Create a new AWS WorkSpace.
.DESCRIPTION
    This script creates a new AWS WorkSpace using the AWS CLI. It validates parameters for directory, bundle, user, and running mode.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsDirectoryId
    The ID of the AWS Directory to register the WorkSpace with.
.PARAMETER AwsWorkspaceBundleId
    The ID of the WorkSpace bundle to use.
.PARAMETER AwsUserName
    The user name for the WorkSpace.
.PARAMETER AwsRunningMode
    The running mode for the WorkSpace (AUTO_STOP or ALWAYS_ON).
.EXAMPLE
    .\aws-cli-create-workspace.ps1 -AwsDirectoryId d-12345678 -AwsWorkspaceBundleId wsb-12345678 -AwsUserName johndoe -AwsRunningMode AUTO_STOP
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId,
    [Parameter(Mandatory)]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceBundleId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@-]{1,64}$')]
    [string]$AwsUserName,
    [Parameter(Mandatory)]
    [ValidateSet('AUTO_STOP','ALWAYS_ON')]
    [string]$AwsRunningMode
)

$ErrorActionPreference = 'Stop'
try {
    aws workspaces create-workspaces `
        --workspaces DirectoryId=$AwsDirectoryId,BundleId=$AwsWorkspaceBundleId,UserName=$AwsUserName,RunningMode=$AwsRunningMode
    Write-Host "Successfully created WorkSpace for user $AwsUserName in directory $AwsDirectoryId."
} catch {
    Write-Error "Failed to create WorkSpace: $_"
    exit 1
}
