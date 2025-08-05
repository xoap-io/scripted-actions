<#
.SYNOPSIS
    Create a new AWS WorkSpace image from an existing WorkSpace.
.DESCRIPTION
    This script creates a new WorkSpace image using the AWS CLI from an existing WorkSpace.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to create the image from.
.PARAMETER AwsImageName
    The name for the new image.
.PARAMETER AwsImageDescription
    (Optional) Description for the new image.
.EXAMPLE
    .\aws-cli-create-workspace-image.ps1 -AwsWorkspaceId ws-12345678 -AwsImageName "MyImage" -AwsImageDescription "Base image for dev"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\- ]{1,64}$')]
    [string]$AwsImageName,
    [Parameter()]
    [string]$AwsImageDescription
)

$ErrorActionPreference = 'Stop'
try {
    $descArg = $AwsImageDescription ? "--description '$AwsImageDescription'" : ""
    aws workspaces create-workspace-image `
        --workspace-id $AwsWorkspaceId `
        --name "$AwsImageName" $descArg
    Write-Host "Successfully created WorkSpace image $AwsImageName."
} catch {
    Write-Error "Failed to create WorkSpace image: $_"
    exit 1
}
