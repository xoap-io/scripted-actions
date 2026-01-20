<#
.SYNOPSIS
    Delete a custom AWS WorkSpace image.
.DESCRIPTION
    This script deletes a custom WorkSpace image using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsImageId
    The ID of the WorkSpace image to delete.
.EXAMPLE
    .\aws-cli-delete-workspace-image.ps1 -AwsImageId wsi-12345678
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^wsi-[a-zA-Z0-9]{8,}$')]
    [string]$AwsImageId
)

$ErrorActionPreference = 'Stop'
try {
    aws workspaces delete-workspace-image --image-id $AwsImageId
    Write-Host "Successfully deleted WorkSpace image $AwsImageId."
} catch {
    Write-Error "Failed to delete WorkSpace image: $_"
    exit 1
}
