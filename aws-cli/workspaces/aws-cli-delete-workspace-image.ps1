<#
.SYNOPSIS
    Delete a custom AWS WorkSpace image.

.DESCRIPTION
    This script deletes a custom WorkSpace image using the AWS CLI.
    Uses the following AWS CLI command:
    aws workspaces delete-workspace-image

.PARAMETER AwsImageId
    The ID of the WorkSpace image to delete.

.EXAMPLE
    .\aws-cli-delete-workspace-image.ps1 -AwsImageId "wsi-12345678"

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
    https://docs.aws.amazon.com/cli/latest/reference/workspaces/delete-workspace-image.html

.COMPONENT
    AWS CLI WorkSpaces
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "The ID of the WorkSpace image to delete")]
    [ValidatePattern('^wsi-[a-zA-Z0-9]{8,}$')]
    [string]$AwsImageId
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error 'AWS CLI is not installed or not in PATH.'
    exit 127
}

try {
    aws workspaces delete-workspace-image --image-id $AwsImageId
    Write-Host "Successfully deleted WorkSpace image $AwsImageId." -ForegroundColor Green
} catch {
    Write-Host "`n❌ Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`n🏁 Script execution completed" -ForegroundColor Green
}
