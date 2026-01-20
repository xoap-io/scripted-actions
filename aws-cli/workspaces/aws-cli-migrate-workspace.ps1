<#
.SYNOPSIS
    Migrate an AWS WorkSpace to a different bundle.

.DESCRIPTION
    This script migrates an AWS WorkSpace to a different bundle.
    The script uses the AWS CLI to migrate the specified AWS WorkSpace to a different bundle.
    The script uses the following AWS CLI command:
    aws workspaces migrate-workspace --source-workspace-id $AwsSourceWorkspaceId --bundle-id $AwsWorkspaceBundleId
    The script sets the ErrorActionPreference to SilentlyContinue to suppress error messages.
    It does not return any output.

.NOTES
    This PowerShell script was developed and optimized for the usage with the XOAP Scripted Actions module.
    The use of the scripts does not require XOAP, but it will make your life easier.
    You are allowed to pull the script from the repository and use it with XOAP or other solutions
    The terms of use for the XOAP platform do not apply to this script. In particular, RIS AG assumes no liability for the function,
    the use and the consequences of the use of this freely available script.
    PowerShell is a product of Microsoft Corporation. XOAP is a product of RIS AG. © RIS AG

.COMPONENT
    AWS CLI

.LINK
    https://github.com/xoap-io/scripted-actions

.PARAMETER AwsSourceWorkspaceId
    Defines the ID of the AWS WorkSpace to migrate.

.PARAMETER AwsWorkspaceBundleId
    Defines the ID of the AWS WorkSpace bundle to migrate to.

#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsSourceWorkspaceId,
    [Parameter(Mandatory)]
    [ValidatePattern('^wsb-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceBundleId
)


$ErrorActionPreference = 'Stop'
try {
    aws workspaces migrate-workspace `
        --source-workspace-id $AwsSourceWorkspaceId `
        --bundle-id $AwsWorkspaceBundleId
    Write-Host "Successfully migrated Workspace $AwsSourceWorkspaceId to bundle $AwsWorkspaceBundleId."
} catch {
    Write-Error "Failed to migrate Workspace: $_"
    exit 1
}
