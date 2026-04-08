<#
.SYNOPSIS
    Delete tags from an AWS Workspace.

.DESCRIPTION
    This script deletes tags from an AWS Workspace using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces delete-tags

.PARAMETER AwsWorkspaceId
    Defines the ID of the AWS Workspace.

.PARAMETER AwsTagKeys
    Defines the keys of the tags to be deleted.

.EXAMPLE
    .\aws-cli-delete-tag.ps1 -AwsWorkspaceId "ws-12345678" -AwsTagKeys "Environment","Owner"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/delete-tags.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the AWS Workspace")]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "The keys of the tags to be deleted")]
    [ValidateNotNullOrEmpty()]
    [string[]]$AwsTagKeys
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    aws workspaces delete-tags `
        --resource-id $AwsWorkspaceId `
        --tag-keys $AwsTagKeys
    Write-Host "Successfully deleted tags from Workspace $AwsWorkspaceId." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
