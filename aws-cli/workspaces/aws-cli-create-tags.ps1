<#
.SYNOPSIS
    Add tags to an AWS WorkSpace.

.DESCRIPTION
    This script adds tags to an AWS WorkSpace using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces create-tags

.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to tag.

.PARAMETER AwsTags
    The tags to add (array of key-value pairs).

.EXAMPLE
    .\aws-cli-create-tags.ps1 -AwsWorkspaceId "ws-12345678" -AwsTags @{Key="Environment";Value="Prod"},@{Key="Owner";Value="Alice"}

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/create-tags.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace to tag")]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "The tags to add (array of key-value pairs)")]
    [ValidateNotNullOrEmpty()]
    [hashtable[]]$AwsTags
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    $tagsArgs = $AwsTags | ForEach-Object { "Key=$($_.Key),Value=$($_.Value)" } -join ' '
    aws workspaces create-tags `
        --resource-id $AwsWorkspaceId `
        --tags $tagsArgs
    Write-Host "Successfully added tags to Workspace $AwsWorkspaceId." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
