<#
.SYNOPSIS
    List users assigned to AWS WorkSpaces in a directory.
.DESCRIPTION
    This script lists users assigned to WorkSpaces in a specified directory using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsDirectoryId
    The ID of the directory to list users for.
.EXAMPLE
    .\aws-cli-list-workspace-users.ps1 -AwsDirectoryId d-12345678
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId
)

$ErrorActionPreference = 'Stop'
try {
    $workspaces = aws workspaces describe-workspaces --directory-id $AwsDirectoryId | ConvertFrom-Json
    $users = $workspaces.Workspaces | Select-Object -ExpandProperty UserName | Sort-Object -Unique
    Write-Host "Users assigned to WorkSpaces in directory ${AwsDirectoryId}:"
    $users | ForEach-Object { Write-Host $_ }
} catch {
    Write-Error "Failed to list WorkSpace users: $_"
    exit 1
}
