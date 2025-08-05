<#
.SYNOPSIS
    Create a custom AWS WorkSpace bundle.
.DESCRIPTION
    This script creates a custom WorkSpace bundle (image + compute type) using the AWS CLI.
.NOTES
    Standalone script for AWS WorkSpaces automation. See XOAP Scripted Actions repo for details.
.COMPONENT
    AWS CLI
.LINK
    https://github.com/xoap-io/scripted-actions
.PARAMETER AwsImageId
    The ID of the WorkSpace image to use.
.PARAMETER AwsComputeTypeName
    The compute type for the bundle (e.g., VALUE, STANDARD, PERFORMANCE, POWER, GRAPHICS).
.PARAMETER AwsBundleName
    The name for the new bundle.
.EXAMPLE
    .\aws-cli-create-workspace-bundle.ps1 -AwsImageId wsi-12345678 -AwsComputeTypeName STANDARD -AwsBundleName "MyBundle"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^wsi-[a-zA-Z0-9]{8,}$')]
    [string]$AwsImageId,
    [Parameter(Mandatory)]
    [ValidateSet('VALUE','STANDARD','PERFORMANCE','POWER','GRAPHICS')]
    [string]$AwsComputeTypeName,
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9._@\- ]{1,64}$')]
    [string]$AwsBundleName
)

$ErrorActionPreference = 'Stop'
try {
    aws workspaces create-workspace-bundle `
        --image-id $AwsImageId `
        --compute-type-name $AwsComputeTypeName `
        --bundle-name "$AwsBundleName"
    Write-Host "Successfully created WorkSpace bundle $AwsBundleName."
} catch {
    Write-Error "Failed to create WorkSpace bundle: $_"
    exit 1
}
