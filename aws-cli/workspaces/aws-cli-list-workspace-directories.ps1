<#
.SYNOPSIS
    List all registered AWS WorkSpaces directories.
.DESCRIPTION
    This script lists all registered directories for AWS WorkSpaces using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.EXAMPLE
    .\aws-cli-list-workspace-directories.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try {
    aws workspaces describe-workspace-directories
    Write-Host "Successfully listed WorkSpace directories."
} catch {
    Write-Error "Failed to list WorkSpace directories: $_"
    exit 1
}
