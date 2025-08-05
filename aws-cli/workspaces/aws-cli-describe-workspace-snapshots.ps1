<#
.SYNOPSIS
    List snapshots for an AWS WorkSpace.
.DESCRIPTION
    This script lists snapshots for a specified WorkSpace using the AWS CLI (if available).
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to list snapshots for.
.EXAMPLE
    .\aws-cli-describe-workspace-snapshots.ps1 -AwsWorkspaceId ws-12345678
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId
)

$ErrorActionPreference = 'Stop'
try {
    aws workspaces describe-workspace-snapshots --workspace-id $AwsWorkspaceId
    Write-Host "Successfully listed snapshots for Workspace $AwsWorkspaceId."
} catch {
    Write-Error "Failed to list Workspace snapshots: $_"
    exit 1
}
