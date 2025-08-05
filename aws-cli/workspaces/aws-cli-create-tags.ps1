<#
.SYNOPSIS
    Add tags to an AWS WorkSpace.
.DESCRIPTION
    This script adds tags to an AWS WorkSpace using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to tag.
.PARAMETER AwsTags
    The tags to add (array of key-value pairs).
.EXAMPLE
    .\aws-cli-create-tags.ps1 -AwsWorkspaceId ws-12345678 -AwsTags @{Key="Environment";Value="Prod"},@{Key="Owner";Value="Alice"}
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [hashtable[]]$AwsTags
)

$ErrorActionPreference = 'Stop'
try {
    $tagsArgs = $AwsTags | ForEach-Object { "Key=$($_.Key),Value=$($_.Value)" } -join ' '
    aws workspaces create-tags `
        --resource-id $AwsWorkspaceId `
        --tags $tagsArgs
    Write-Host "Successfully added tags to Workspace $AwsWorkspaceId."
} catch {
    Write-Error "Failed to add tags: $_"
    exit 1
}
