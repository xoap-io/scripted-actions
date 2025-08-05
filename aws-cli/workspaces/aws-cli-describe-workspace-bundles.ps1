<#
.SYNOPSIS
    List available AWS WorkSpace bundles.
.DESCRIPTION
    This script lists all available WorkSpace bundles using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.EXAMPLE
    .\aws-cli-describe-workspace-bundles.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
try {
    aws workspaces describe-workspace-bundles
    Write-Host "Successfully listed WorkSpace bundles."
} catch {
    Write-Error "Failed to list WorkSpace bundles: $_"
    exit 1
}
