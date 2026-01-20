<#
.SYNOPSIS
    Attempt recovery of an AWS WorkSpace in ERROR state.
.DESCRIPTION
    This script attempts to recover a WorkSpace in ERROR state using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to recover.
.EXAMPLE
    .\aws-cli-recover-workspace.ps1 -AwsWorkspaceId ws-12345678
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId
)

$ErrorActionPreference = 'Stop'
try {
    aws workspaces recover-workspace --workspace-id $AwsWorkspaceId
    Write-Host "Successfully initiated recovery for Workspace $AwsWorkspaceId."
} catch {
    Write-Error "Failed to recover Workspace: $_"
    exit 1
}
