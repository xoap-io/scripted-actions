<#
.SYNOPSIS
    Create a new AWS WorkSpace image from an existing WorkSpace.

.DESCRIPTION
    This script creates a new WorkSpace image using the AWS CLI from an existing WorkSpace.
    Uses the following AWS CLI command:
    aws workspaces create-workspace-image

.PARAMETER AwsWorkspaceId
    The ID of the WorkSpace to create the image from.

.PARAMETER AwsImageName
    The name for the new image.

.PARAMETER AwsImageDescription
    Description for the new image (optional).

.EXAMPLE
    .\aws-cli-create-workspace-image.ps1 -AwsWorkspaceId "ws-12345678" -AwsImageName "MyImage" -AwsImageDescription "Base image for dev"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/create-workspace-image.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace to create the image from")]
    [ValidatePattern('^ws-[a-zA-Z0-9]{8,}$')]
    [string]$AwsWorkspaceId,

    [Parameter(Mandatory = $true, HelpMessage = "The name for the new image")]
    [ValidatePattern('^[a-zA-Z0-9._@\- ]{1,64}$')]
    [string]$AwsImageName,

    [Parameter(Mandatory = $false, HelpMessage = "Description for the new image")]
    [string]$AwsImageDescription
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    if ($AwsImageDescription) {
        aws workspaces create-workspace-image `
            --workspace-id $AwsWorkspaceId `
            --name "$AwsImageName" `
            --description "$AwsImageDescription"
    } else {
        aws workspaces create-workspace-image `
            --workspace-id $AwsWorkspaceId `
            --name "$AwsImageName"
    }
    Write-Host "Successfully created WorkSpace image $AwsImageName." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
