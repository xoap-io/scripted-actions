<#
.SYNOPSIS
    List available AWS WorkSpaces images.
.DESCRIPTION
    This script lists available images for AWS WorkSpaces using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.EXAMPLE
    .\aws-cli-list-available-workspace-images.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try {
    aws workspaces describe-workspace-images
    Write-Host "Successfully listed available WorkSpace images."
} catch {
    Write-Error "Failed to list WorkSpace images: $_"
    exit 1
}
