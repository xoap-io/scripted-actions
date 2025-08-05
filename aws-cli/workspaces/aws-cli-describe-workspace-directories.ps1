<#
.SYNOPSIS
    Describe AWS WorkSpaces directories.
.DESCRIPTION
    This script gets details about registered AWS WorkSpaces directories using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsDirectoryId
    (Optional) The ID of the directory to describe.
.EXAMPLE
    .\aws-cli-describe-workspace-directories.ps1 -AwsDirectoryId d-12345678
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidatePattern('^d-[a-zA-Z0-9]{8,}$')]
    [string]$AwsDirectoryId
)

$ErrorActionPreference = 'Stop'
try {
    if ($AwsDirectoryId) {
        aws workspaces describe-workspace-directories --directory-ids $AwsDirectoryId
    } else {
        aws workspaces describe-workspace-directories
    }
    Write-Host "Successfully described WorkSpace directories."
} catch {
    Write-Error "Failed to describe WorkSpace directories: $_"
    exit 1
}
