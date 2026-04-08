<#
.SYNOPSIS
    Modifies the state of an AWS Workspace.

.DESCRIPTION
    This script modifies the state of an AWS Workspace using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces modify-workspace-state

.PARAMETER AwsWorkspaceId
    Defines the ID of the AWS Workspace.

.PARAMETER AwsWorkspaceState
    Defines the state of the AWS Workspace.

.EXAMPLE
    .\aws-cli-modify-workspace-state.ps1 -AwsWorkspaceId "ws-12345678" -AwsWorkspaceState "AVAILABLE"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/modify-workspace-state.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS Workspace")]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "The state of the AWS Workspace")]
    [ValidateSet('AVAILABLE', 'ERROR', 'REBOOTING', 'STARTING', 'STOPPED', 'STOPPING', 'TERMINATED')]
    [string]$AwsWorkspaceState
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    aws workspaces modify-workspace-state `
        --workspace-id $AwsWorkspaceId `
        --workspace-state $AwsWorkspaceState
    Write-Host "Successfully modified state of Workspace $AwsWorkspaceId to $AwsWorkspaceState." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
